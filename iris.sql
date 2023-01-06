/* Creating database for Iris dataset*/
CREATE DATABASE irissql
GO
USE irissql
GO

/* creating table to store Iris data*/
DROP TABLE IF EXISTS iris_data;

CREATE TABLE iris_data (
  id INT NOT NULL IDENTITY PRIMARY KEY,
  "Sepal.Length" FLOAT NOT NULL, 
  "Sepal.Width" FLOAT NOT NULL,
  "Petal.Length" FLOAT NOT NULL, 
  "Petal.Width" FLOAT NOT NULL,
  "Species" VARCHAR(100) NOT NULL
);
Go

/* mapping the string column into integer */
Alter table Iris add SpeciesID int;
Go

update Iris
set SpeciesID =
	CASE Species 
		WHEN ('Iris-setosa') THEN 0
		WHEN ('Iris-versicolor') THEN 1
		WHEN ('Iris-virginica') THEN 2
	END
GO

/* creating a table to store the trained machine learning model */
DROP TABLE IF EXISTS iris_models;
GO

CREATE TABLE iris_models (
  model_name VARCHAR(50) NOT NULL DEFAULT('default model') PRIMARY KEY,
  model VARBINARY(MAX) NOT NULL
);
GO

/* creating a procedure that trains the iris dataset (training part only) using random forest classifier*/
Drop procedure if exists generate_iris_model;
Go
CREATE PROCEDURE generate_iris_model (@trained_model VARBINARY(max) OUTPUT)
AS
BEGIN
EXECUTE sp_execute_external_script @language = N'Python',
@script = N'
import pickle
from sklearn.ensemble import RandomForestClassifier
rf = RandomForestClassifier()
trained_model = pickle.dumps(rf.fit(Iris[["SepalLengthCm", "SepalWidthCm", "PetalLengthCm", "PetalWidthCm"]], Iris[["SpeciesID"]].values.ravel()))
'
, @input_data_1 = N'select "SepalLengthCm", "SepalWidthCm", "PetalLengthCm", "PetalWidthCm", "SpeciesID" from Iris'
, @input_data_1_name = N'Iris'
, @params = N'@trained_model varbinary(max) OUTPUT'
, @trained_model = @trained_model OUTPUT;
END;
GO

/* executing the training procedure */
DECLARE @model varbinary(max);
DECLARE @new_model_name varchar(50)
SET @new_model_name = 'Random Forest'
EXECUTE generate_iris_model @model OUTPUT;
DELETE iris_models WHERE model_name = 'Naive Bayes';
INSERT INTO iris_models (model_name, model) values(@new_model_name, @model);
GO

/* creating a procedure to test the trained model*/
DROP PROCEDURE IF EXISTS predict_species;
GO
CREATE PROCEDURE predict_species (@model VARCHAR(100))
AS
BEGIN
DECLARE @rf_model VARBINARY(max) = (
SELECT model
FROM iris_models
WHERE model_name = @model
);

EXECUTE sp_execute_external_script @language = N'Python',
@script = N'
import pickle
irismodel = pickle.loads(rf_model)

_pred = irismodel.predict(Iris[["SepalLengthCm", "SepalWidthCm", "PetalLengthCm", "PetalWidthCm"]])
_actual = Iris["SpeciesID"].tolist()
Iris["PredictedSpecies"] = _pred
OutputDataSet = Iris[["SpeciesID","PredictedSpecies"]] 
print(OutputDataSet)
'
, @input_data_1 = N'select "SepalLengthCm", "SepalWidthCm", "PetalLengthCm", "PetalWidthCm", "SpeciesID" from Iris'
, @input_data_1_name = N'Iris'
, @params = N'@rf_model varbinary(max)'
, @rf_model = @rf_model

WITH RESULT SETS((
    "id" INT
    , "SpeciesID" INT
    , "SpeciesId.Predicted" INT
    ));
END;
GO

/* executing the testing procedure */
EXECUTE predict_species 'Random Forest';
GO