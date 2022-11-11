-- Create a data set if does not exist
CREATE SCHEMA IF NOT EXISTS imdb_reviews_bow;


-- Select unique reviews with only negative and positive labels
CREATE OR REPLACE TABLE imdb_reviews_bow.processed_reviews AS (
  SELECT
    ROW_NUMBER() OVER () AS review_number,
    REGEXP_EXTRACT_ALL(LOWER(review), '[a-z]{2,}') AS words,
    label,
    split
  FROM (
    SELECT
      DISTINCT review,
      label,
      split
    FROM
      `bigquery-public-data.imdb.reviews`
    WHERE
      label IN ('Negative', 'Positive')
  )
);


-- Create a vocabulary with topk words using its frequency
CREATE OR REPLACE TABLE imdb_reviews_bow.topk_words AS (
  SELECT
    word,
    word_frequency,
    word_index
  FROM (
    SELECT
      word,
      word_frequency,
      ROW_NUMBER() OVER (ORDER BY word_frequency DESC) AS word_index
    FROM (
      SELECT
        word,
        COUNT(word) AS word_frequency
      FROM
        imdb_reviews_bow.processed_reviews,
        UNNEST(words) AS word
      WHERE
        split = "train"
      GROUP BY
        word
    )
  )
  WHERE
    word_index < 20000 # Select top ~20k words based on word count
);


-- Generate a sparse feature by aggregating word_index and word_frequency in each review.
CREATE OR REPLACE TABLE imdb_reviews_bow.sparse_feature AS (
  SELECT
    review_number,
    ARRAY_AGG(STRUCT(word_index, word_frequency)) AS feature,
    label,
    split
  FROM (
    SELECT
      DISTINCT review_number,
      word,
      label,
      split
    FROM
      imdb_reviews_bow.processed_reviews,
      UNNEST(words) AS word
    WHERE
      word IN (SELECT word FROM imdb_reviews_bow.topk_words)
  ) AS word_list
  LEFT JOIN
    imdb_reviews_bow.topk_words AS topk_words
    ON
      word_list.word = topk_words.word
  GROUP BY
    review_number,
    label,
    split
);


-- Train a logistic regression classifier using the data with sparse feature
CREATE OR REPLACE MODEL imdb_reviews_bow.logistic_reg_classifier
  TRANSFORM (
    * EXCEPT (
        review_number
      )
  )
  OPTIONS(
    MODEL_TYPE='LOGISTIC_REG',
    DATA_SPLIT_METHOD='AUTO_SPLIT',
    INPUT_LABEL_COLS = ['label'],
    MAX_ITERATIONS=3
  ) AS
  SELECT
    review_number,
    feature,
    label
  FROM
     imdb_reviews_bow.sparse_feature
  WHERE
    split = "train"
;


-- Evaluate the trained logistic regression classifier
SELECT * FROM ML.EVALUATE(MODEL imdb_reviews_bow.logistic_reg_classifier);


-- Evaluate the trained logistic regression classifier using test data
SELECT * FROM ML.EVALUATE(MODEL imdb_reviews_bow.logistic_reg_classifier,
  (
    SELECT
      review_number,
      feature,
      label
    FROM
      imdb_reviews_bow.sparse_feature
    WHERE
      split = "test"
  )
);

WITH
  -- Create a user defined reviews
  user_defined_reviews AS (
    SELECT
      ROW_NUMBER() OVER () AS review_number,
      REGEXP_EXTRACT_ALL(LOWER(review), '[a-z]{2,}') AS words
    FROM (
      SELECT "can't wait for a new one" AS review UNION ALL
      SELECT "I don't like this movie" AS review UNION ALL
      SELECT "the best has yet to come" AS review
    )
  ),


  -- Create a sparse feature from user defined reviews
  user_defined_sparse_feature AS (
    SELECT
      review_number,
      ARRAY_AGG(STRUCT(word_index, word_frequency)) AS feature
    FROM (
      SELECT
        DISTINCT review_number,
        word
      FROM
        user_defined_reviews,
        UNNEST(words) as word
      WHERE
        word IN (SELECT word FROM imdb_reviews_bow.topk_words)
    ) AS word_list
    LEFT JOIN
      imdb_reviews_bow.topk_words AS topk_words
      ON
        word_list.word = topk_words.word
    GROUP BY
      review_number
  )


-- Evaluate the trained model using user defined data
SELECT review_number, predicted_label FROM ML.PREDICT(MODEL imdb_reviews_bow.logistic_reg_classifier,
  (
    SELECT
      *
    FROM
      user_defined_sparse_feature
  )
);
