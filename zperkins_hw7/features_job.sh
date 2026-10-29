#!/bin/bash
#SBATCH --job-name=zperkins_features
#SBATCH --partition=Centaurus
#SBATCH --cpus-per-task=2
#SBATCH --mem=160G
#SBATCH --time=02:00:00
#SBATCH --output=features_%j.out

set -e

cd ~/zperkins_hw7

source /projects/class/spoa4001_u01/SportsTrackingTransformer/.venv/bin/activate

python -u src/datasets.py

echo "Transformer datasets completed successfully!"