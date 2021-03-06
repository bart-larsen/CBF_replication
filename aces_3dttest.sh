#!/bin/bash

### This script makes a list of scans and covariates to pass to afni's 3dttest++ ###
### Update: we can now optionally smooth the data.

#If smoothing is desired set this variable to true and set desired FWHM
smooth=false
FWHM=8

# Number of parallel cores
nCores=30

# set variables and initialize files
mask=/cbica/projects/Kristin_CBF/data/aces_flameo_2/included_intersection_mask.nii.gz
cov_file="aces_covariates.txt"
echo "subject age_months sex log_aces relMeanRMSMotion" > $cov_file
scan_file="aces_scans.txt"
echo -n > $scan_file

# Loop over the data file that includes subID and covariates
while IFS=, read bblid age_months sex aces_score_total log_aces relMeanRMSMotion other; do
	dataDir="/cbica/projects/Kristin_CBF/data/asl/xcpout/xcpengine/sub-${bblid}/norm/"
	
	if [[ "$bblid" == *"bblid"* ]]; then
                continue
		# skip header row
	fi

	# Smooth if needed.
	if [[ $smooth ]]; then
		# we need to smooth
		# check if we already have a smoothed file
		smooth_filename="sub-${bblid}_cbfStd_sm${FWHM}.nii.gz"
		if [ ! -e ${dataDir}/${smooth_filename} ]; then
			#sub_mask=${dataDir}/sub-${bblid}_maskStd.nii.gz
			3dBlurToFWHM -FWHM $FWHM -automask -prefix ${dataDir}/${smooth_filename} -input ${dataDir}/"sub-${bblid}_cbfStd.nii.gz"
		fi
		scan_filename=${smooth_filename}
	else
		scan_filename="sub-${bblid}_cbfStd.nii.gz"
	fi
		

	# Append info to the scan list and covariates files.
	sub_label="sub-${bblid}" # This is the label for the scan
	echo "$sub_label ${dataDir}/${scan_filename}" >> $scan_file
	echo "$sub_label $age_months $sex $log_aces $relMeanRMSMotion" >> $cov_file


done </cbica/projects/Kristin_CBF/data/aces_flameo_2/model_aces.csv 

# First concatenate all the scans (this will be useful when looking at results)
3dbucket -prefix scan_bucket.nii.gz -overwrite $(cat aces_scans.txt | cut -d' ' -f2-)

# Get the scan list of scans
scans=$(cat $scan_file)

# Call to 3dttest++
# -prefix: output filename
# -overwrite: overwrite the output file if it exists
# -mask: give the mask file: THIS IS IMPORTANT
# -setA label scanlist: we are labeling this "cbf" but can pick anything, also passing our scan list
# -ClustSim #cores: This is a critical step (but takes a while). Can paralellize by setting #cores (20 here)
## Highly recommend reading the help for this fx to understand ClustSim, but in brief:
## ClustSim uses random permutations of your dataset to simulate the null model for your cluster correction.
## It is super convenient because 1) it does everything for you, and 2) it appends the output to your output .nii.gz file which makes it super easy to visualize your results.

# Change output filename depending on if we are smoothing
if [[ $smooth ]]; then
	3dttest++ -prefix aces_result_clustsim_sm${FWHM}.nii.gz -overwrite -mask $mask -setA cbf $scans -covariates $cov_file -Clustsim $nCores
else
	3dttest++ -prefix aces_result_clustsim.nii.gz -overwrite -mask $mask -setA cbf $scans -covariates $cov_file -Clustsim $nCores
fi
