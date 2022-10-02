# aws-parallelcluster-rsw
An opinionated setup of RStudio Workbench (RSW) for the use with AWS ParallelCluster

# QuickStart

## python venv (one time setup) 

```
python3 -m venv .venv 
source .venv/bin/activate.fish
pip install --upgrade pip setuptools wheel
pip install aws-parallelcluster 
```

## Edit config variables

Edit lines 3 to 9 of `deploy.sh` to reflect the appropriate details of your environment. 

## Start the deployment 

Run `./deploy.sh`. This will copy scripts and config files to the existing S3 bucket and trigger the installation of the HPC cluster. 


# More information 

See [doc](./doc) folder. 
