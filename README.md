# SQL-ML-Classification


This repository contains SQL scripts to create a database for the Iris dataset, store data, train a machine learning model using SQL Server's external script execution capabilities, and predict species based on the trained model.

## SQL Scripts Overview

### 1. Creating Database and Tables

```sql
/* Creating database for Iris dataset */
CREATE DATABASE irissql;
GO

USE irissql;
GO

/* Creating table to store Iris data */
DROP TABLE IF EXISTS Iris;

CREATE TABLE Iris (
  id INT NOT NULL IDENTITY PRIMARY KEY,
  "Sepal.Length" FLOAT NOT NULL, 
  "Sepal.Width" FLOAT NOT NULL,
  "Petal.Length" FLOAT NOT NULL, 
  "Petal.Width" FLOAT NOT NULL,
  "Species" VARCHAR(100) NOT NULL,
  SpeciesID INT
);
GO

/* Mapping the string column into integer */
UPDATE Iris
SET SpeciesID =
    CASE Species 
        WHEN 'Iris-setosa' THEN 0
        WHEN 'Iris-versicolor' THEN 1
        WHEN 'Iris-virginica' THEN 2
    END;
GO
```

### 2. Storing Trained Machine Learning Models

```sql
/* Creating a table to store the trained machine learning model */
DROP TABLE IF EXISTS iris_models;
GO

CREATE TABLE iris_models (
  model_name VARCHAR(50) NOT NULL DEFAULT('default model') PRIMARY KEY,
  model VARBINARY(MAX) NOT NULL
);
GO
```

### 3. Training and Storing Machine Learning Model

```sql
/* Creating a procedure that trains the iris dataset (training part only) using random forest classifier */
DROP PROCEDURE IF EXISTS generate_iris_model;
GO

CREATE PROCEDURE generate_iris_model (@trained_model VARBINARY(MAX) OUTPUT)
AS
BEGIN
    EXECUTE sp_execute_external_script @language = N'Python',
    @script = N'
    import pickle
    from sklearn.ensemble import RandomForestClassifier
    rf = RandomForestClassifier()
    trained_model = pickle.dumps(rf.fit(Iris[["Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width"]], Iris[["SpeciesID"]].values.ravel()))
    '
    , @input_data_1 = N'select "Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "SpeciesID" from Iris'
    , @input_data_1_name = N'Iris'
    , @params = N'@trained_model VARBINARY(MAX) OUTPUT'
    , @trained_model = @trained_model OUTPUT;
END;
GO

/* Executing the training procedure */
DECLARE @model VARBINARY(MAX);
DECLARE @new_model_name VARCHAR(50);
SET @new_model_name = 'Random Forest';
EXECUTE generate_iris_model @model OUTPUT;
DELETE iris_models WHERE model_name = 'Random Forest';
INSERT INTO iris_models (model_name, model) VALUES (@new_model_name, @model);
GO
```

### 4. Predicting Species Using Trained Model

```sql
/* Creating a procedure to test the trained model */
DROP PROCEDURE IF EXISTS predict_species;
GO

CREATE PROCEDURE predict_species (@model VARCHAR(100))
AS
BEGIN
    DECLARE @rf_model VARBINARY(MAX) = (
    SELECT model
    FROM iris_models
    WHERE model_name = @model
    );

    EXECUTE sp_execute_external_script @language = N'Python',
    @script = N'
    import pickle
    irismodel = pickle.loads(rf_model)

    _pred = irismodel.predict(Iris[["Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width"]])
    Iris["PredictedSpecies"] = _pred
    OutputDataSet = Iris[["SpeciesID", "PredictedSpecies"]]
    print(OutputDataSet)
    '
    , @input_data_1 = N'select "Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "SpeciesID" from Iris'
    , @input_data_1_name = N'Iris'
    , @params = N'@rf_model VARBINARY(MAX)'
    , @rf_model = @rf_model
    WITH RESULT SETS((
        "id" INT,
        "SpeciesID" INT,
        "SpeciesId.Predicted" INT
    ));
END;
GO

/* Executing the testing procedure */
EXECUTE predict_species 'Random Forest';
GO
```

## Purpose

The purpose of this repository is to demonstrate how to set up a SQL database for the Iris dataset, train a machine learning model using SQL Server's capabilities, and predict species based on the trained model. It showcases the integration of SQL and Python for machine learning tasks within a database environment.

## Data Used

The Iris dataset can be found [here](https://archive.ics.uci.edu/dataset/53/iris)

The Iris dataset is a classic dataset in the field of machine learning and statistics. It was introduced by the British statistician and biologist Ronald Fisher in his 1936 paper "The Use of Multiple Measurements in Taxonomic Problems" as an example of linear discriminant analysis. The dataset consists of 150 samples of iris flowers, each with four features (attributes) describing the length and width of the sepals and petals, as well as their corresponding species classification.

Features
- Sepal Length: Length of the sepal (in centimeters).
- Sepal Width: Width of the sepal (in centimeters).
- Petal Length: Length of the petal (in centimeters).
- Petal Width: Width of the petal (in centimeters).
Target Variable
- Species: The species of iris flowers, which are categorized into three classes:
  - Iris Setosa
  - Iris Versicolor
  - Iris Virginica
