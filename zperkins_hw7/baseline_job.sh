#!/bin/bash
#SBATCH --job-name=zperkins_baseline
#SBATCH --partition=GPU
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=96G
#SBATCH --time=02:00:00
#SBATCH --output=baseline_%j.out

set -e

cd ~/zperkins_hw7

source /projects/class/spoa4001_u01/SportsTrackingTransformer/.venv/bin/activate

python -u src/train.py \
    --device 0 \
    --model_type transformer \
    --hparam_search_iters 1 \
    --patience 5

echo "Baseline model completed successfully!"
