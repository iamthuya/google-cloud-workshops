-- Select top 10 rows
SELECT
   *
FROM
   `bigquery-public-data.imdb.reviews`
LIMIT 10;


-- Select review count and unique review count
SELECT
   COUNT(review) AS review_count,
   COUNT(DISTINCT review) AS unique_review_count
FROM
   `bigquery-public-data.imdb.reviews`;


-- Select label and label count
SELECT
   label,
   count(*) AS label_count
FROM
   `bigquery-public-data.imdb.reviews`
GROUP BY
   label;


-- Select label and label count with only negative and positive labels
SELECT
   label,
   count(*) AS label_count
FROM
   `bigquery-public-data.imdb.reviews`
WHERE
   label IN ("Negative", "Positive")
GROUP BY
   label;


-- Select split and split count with only negative and positive labels
SELECT
   split,
   count(*) AS split_count
FROM
   `bigquery-public-data.imdb.reviews`
WHERE
   label IN ("Negative", "Positive")
GROUP BY
   split;


-- Select split, label, and split count with only negative and positive labels
SELECT
   split,
   label,
   count(*) AS split_count
FROM
   `bigquery-public-data.imdb.reviews`
WHERE
   label IN ("Negative", "Positive")
GROUP BY
   split,
   label;


-- Select unique review, label, and split with only negative and positive labels
SELECT
   DISTINCT review,
   label,
   split
FROM
   `bigquery-public-data.imdb.reviews`
WHERE
   label IN ("Negative", "Positive");