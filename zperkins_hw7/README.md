## Question 1: Running the Original Model

I ran the SportsTrackingTransformer model using the 2024 NFL Big Data Bowl tracking data.

The model predicts tackle locations using NFL player-tracking data.

I trained the Transformer using:
- 1 Transformer layer
- Model dimension: 32
- Learning rate: 0.0001
- 5 training epochs

The original model completed successfully (HPC Job 23905).

Results:
- Validation loss: 3.580
- Test prediction error (ADE): 6.095 yards

## Question 2: Changing a Parameter

THe parameter I changed was increasing the learning rate from 0.0001 to 0.0005 while keeping the other settings the same.

The modified model completed successfully (HPC Job 23907).

Results:
- Validation loss: 3.090
- Test prediction error (ADE): 5.415 yards

The modified model reduced test prediction error by approximately 11.2%.

This suggests the higher learning rate helped the model learn faster during our five-epoch experiment.


## Screenshots

The screenshots folder contains evidence of the HPC runs, parameter change, and model comparison.

The full results are saved in `results/model_comparison.csv`.