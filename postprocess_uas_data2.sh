#!/bin/bash

# Tips and tricks:
# on modex, first run
# module load gdal/3.1.2_hdf4-gcc840
# use a conda env
# conda activate /data2/sserbin/conda_envs/geospatial

# INPUT=/data2/RS_GIS_Data/UAS_Data/NGEEArctic/UAS_Flights/Seward_2021/Skydio2/Council/20210821/Flight_1/L1/postprocess/chm
# OUTPUT=/data2/RS_GIS_Data/UAS_Data/NGEEArctic/UAS_Flights/Seward_2021/Skydio2/Council/20210821/Flight_1/L2/25m_window
# ./postprocess_uas_data2.sh -ir=$INPUT -or=$OUTPUT

# Set processing options
for i in "$@"
do
case $i in
    -ir=*|--input_root=*)
    input_root="${i#*=}"
    shift # past argument=value
    ;;
    -or=*|--output_root=*)
    output_root="${i#*=}"
    shift # past argument=value
    ;;
    -comp=*|--compression=*)
    compression="${i#*=}"
    shift # past argument=value
    ;;
    -if=*|--input_file=*)
    input_file="${i#*=}"
    shift # past argument=value
    ;;
    -odem=*|--output_dem=*)
    output_dem="${i#*=}"
    shift # past argument=value
    ;;
    -ochm=*|--output_chm=*)
    output_chm="${i#*=}"
    shift # past argument=value
    ;;
    *)
        # unknown option
    ;;
esac
done

# defaults
input_root="${input_root:-$PWD}"
output_root="${output_root:-$PWD/output}"
compression="${compression:-LZW}" # need to replace hard-coded with this flag value
cog_file="${cog_file:-TRUE}"  # at this point always true.
input_file="${input_file:-rgb_dsm_dem_chm_stack_for_rgbdsm_stack}"
output_dem="${output_dem:-dem}"
output_chm="${output_chm:-chm}"
img_file_type="${img_file_type:-.tif}"

# show options
echo " "
echo " "
echo "***************** Directories  *****************"
echo "*** Current directory: ${PWD} "
echo "*** Input file directory: ${input_root} "
echo "*** Output file directory: ${output_root} "
echo " "
echo "***************** Post-processing options *****************"
echo "*** DEM and CHM file name: ${input_file} "
echo "*** Compression: ${compression} "
echo "*** COG: ${cog_file} "
echo " "
echo " "

mkdir -p ${output_root}

echo " "
echo "***************** Post-processing images  *****************"
echo " "
echo "*** Creating final DEM image"
gdal_translate -of COG -co NUM_THREADS=8 -co BLOCKSIZE=256 -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=IF_SAFER -b 5 \
--config GDAL_CACHEMAX 80% --config GDAL_NUM_THREADS 8 ${input_root}"/"${input_file} ${output_root}"/"${output_dem}${img_file_type}

# kmz, png
zMin=`gdalinfo -mm ${output_root}"/"${output_dem}${img_file_type} | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 1 | cut -d . -f 1`
zMax=`gdalinfo -mm ${output_root}"/"${output_dem}${img_file_type} | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 2 | cut -d . -f 1`
gdal_translate -of KMLSUPEROVERLAY -co FORMAT=JPEG -scale ${zMin} ${zMax} -outsize 80% 80% ${output_root}"/"${output_dem}${img_file_type} \
${output_root}"/"${output_dem}".kmz" --config GDAL_CACHEMAX 80%

gdal_translate -of PNG -ot Byte -scale ${zMin} ${zMax} -outsize 70% 70% ${output_root}"/"${output_dem}${img_file_type} \
${output_root}"/"${output_dem}".png" --config GDAL_CACHEMAX 80%


echo " "
echo "*** Creating final CHM image"
gdal_translate -of COG -co NUM_THREADS=8 -co BLOCKSIZE=256 -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=IF_SAFER -b 6 \
--config GDAL_CACHEMAX 80% --config GDAL_NUM_THREADS 8 ${input_root}"/"${input_file} ${output_root}"/"${output_chm}${img_file_type}

# kmz, png
zMin=`gdalinfo -mm ${output_root}"/"${output_chm}${img_file_type} | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 1 | cut -d . -f 1`
zMax=`gdalinfo -mm ${output_root}"/"${output_chm}${img_file_type} | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 2 | cut -d . -f 1`
gdal_translate -of KMLSUPEROVERLAY -co FORMAT=JPEG -scale ${zMin} ${zMax} -outsize 80% 80% ${output_root}"/"${output_chm}${img_file_type} \
${output_root}"/"${output_chm}".kmz" --config GDAL_CACHEMAX 80%

gdal_translate -of PNG -ot Byte -scale ${zMin} ${zMax} -outsize 70% 70% ${output_root}"/"${output_chm}${img_file_type} \
${output_root}"/"${output_chm}".png" --config GDAL_CACHEMAX 80%

echo " "
echo " "
echo "DONE!!"

####
# EOF