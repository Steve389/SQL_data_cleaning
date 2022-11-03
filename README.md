# SQL_data_cleaning
Data cleaning performed using Structured Query Language

In this project, I analyzed the Nashville Housing Dataset and used SQL to perform data cleaning.

## 1. Importing dataset into MySQL
This stage revealed itself to be quite tricky because for some reason (maybe the size of the dataset) I could not import 
the data into MySQL using either the Table Data Import Wizard or the LOAD DATA INFILE function. 
As a result, I decided to import the dataset using a Python script. All the code can be found in the 'CSV to SQL connector' file.

## 2. Data Cleaning

At this point, I could go ahead and start cleaning the dataset.
The following were the main steps of my process:

- Imputing missing values. 
- Breaking out one columns into distinct and more usable columns.
- Dealing with unconsistent data values.
- Removing duplicates.
- Deleting unused columns
