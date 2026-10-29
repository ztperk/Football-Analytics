
from pathlib import Path
import polars as pl

# Paths to our two trained models
models = {
    "Original": "models/transformer/M32_L1_LR1e-04/checkpoints",
    "Modified": "models/transformer/M32_L1_LR5e-04/checkpoints",
}

results = []

for name, folder in models.items():
    # Find the saved predictions
    files = list(Path(folder).glob("*.results.parquet"))
    if len(files) != 1:
        raise ValueError(f"Expected one results file in {folder}")

    # Read predictions and exclude mirrored duplicate frames
    df = pl.scan_parquet(files[0]).filter(
        pl.col("mirrored") == False
    )

    # Calculate distance between predicted and actual tackle
    df = df.with_columns(
        (
            (pl.col("tackle_x_pred") - pl.col("tackle_x")) ** 2
            + (pl.col("tackle_y_pred") - pl.col("tackle_y")) ** 2
        ).sqrt().alias("distance_yards")
    )

    # Average Displacement Error for each dataset
    summary = (
        df.group_by("dataset_split")
        .agg(
            pl.len().alias("frames"),
            pl.col("distance_yards").mean().alias("ADE_yards"),
        )
        .with_columns(pl.lit(name).alias("model"))
        .select(["model", "dataset_split", "frames", "ADE_yards"])
        .collect()
    )

    results.append(summary)

comparison = pl.concat(results).sort(["dataset_split", "model"])

print("\nMODEL COMPARISON")
print(comparison)

# Save results for GitHub submission
Path("results").mkdir(exist_ok=True)
comparison.write_csv("results/model_comparison.csv")

print("\nSaved results/model_comparison.csv")
