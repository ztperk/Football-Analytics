#!/bin/bash
#SBATCH --job-name=zperkins_prep
#SBATCH --partition=Centaurus
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=01:30:00
#SBATCH --output=prep_%j.out

set -e

cd ~/zperkins_hw7

# Activate the existing Python environment
source /projects/class/spoa4001_u01/SportsTrackingTransformer/.venv/bin/activate

# Prepare the Big Data Bowl data
python -u src/prep_data.py

echo "Data preparation completed successfully!"
