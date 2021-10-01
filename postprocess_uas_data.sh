#!/bin/bash

# Tips and tricks:
# on modex, first run
# module load gdal/3.1.2_hdf4-gcc840
# use a conda env
# conda activate /data2/sserbin/conda_envs/geospatial

# INPUT=/data2/RS_GIS_Data/UAS_Data/NGEEArctic/UAS_Flights/Seward_2021/Skydio2/Kougarok/20210816/Flight_1/L1
# OUTPUT=/data2/RS_GIS_Data/UAS_Data/NGEEArctic/UAS_Flights/Seward_2021/Skydio2/Kougarok/20210816/Flight_1/L1/postprocess
# ./postprocess_uas_data.sh -ir=$INPUT -or=$OUTPUT

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
    -cog=*|--cog_file=*)
    cog_file="${i#*=}"
    shift # past argument=value
    ;;
    -ortho=*|--ortho_file=*)
    ortho_file="${i#*=}"
    shift # past argument=value
    ;;
    -dsm=*|--dsm_file=*)
    dsm_file="${i#*=}"
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
ortho_file="${ortho_file:-odm_orthophoto}"
dsm_file="${dsm_file:-dsm}"
img_file_type="${img_file_type:-.tif}"

# show options
echo " "
echo " "
echo "***************** Directories  *****************"
echo "*** Current directory: ${PWD} "
echo "*** Input file directory: ${input_root} "
echo "*** Output file directory: ${output_root} "
echo " "
echo "***************** Preprocessing options *****************"
echo "*** orthophoto name: ${ortho_file} "
echo "*** dsm name: ${dsm_file} "
echo "*** Compression: ${compression} "
echo "*** COG: ${cog_file} "
echo " "
echo " "

# create output directory for processing images
mkdir -p ${output_root}

echo " "
echo "***************** Pre-processing images  *****************"
echo "*** split: ${ortho_file} into bands"
gdal_translate -ot Float32 -of GTiff -co "TILED=YES" -b 1 ${input_root}"/"${ortho_file}${img_file_type} \
${output_root}"/"${ortho_file}_red${img_file_type} 
gdal_translate -ot Float32 -of GTiff -co "TILED=YES" -b 2 ${input_root}"/"${ortho_file}${img_file_type} \
${output_root}"/"${ortho_file}_green${img_file_type}
gdal_translate -ot Float32 -of GTiff -co "TILED=YES" -b 3 ${input_root}"/"${ortho_file}${img_file_type} \
${output_root}"/"${ortho_file}_blue${img_file_type}

echo " "
echo "*** change dsm compression: ${dsm_file}"
gdal_translate -co TILED=YES -co COMPRESS=LZW ${input_root}"/"${dsm_file}${img_file_type} \
${output_root}"/"${dsm_file}${img_file_type} --config GDAL_CACHEMAX 80%

echo " "
echo "*** build RGM+DSM layerstack"
gdal_merge.py -v -of GTiff -separate -o ${output_root}"/"rgbdsm_stack.tif ${output_root}"/"${ortho_file}_red${img_file_type} \
${output_root}"/"${ortho_file}_green${img_file_type} \
${output_root}"/"${ortho_file}_blue${img_file_type} ${output_root}"/"${dsm_file}${img_file_type} -co TILED=YES -co COMPRESS=LZW \
-co NUM_THREADS=8 --config GDAL_CACHEMAX 80%

echo " "
echo " "
echo "***************** Post-processing images  *****************"
# create final orhtophoto image as a tiled COG with overlays that will also open in ENVI (i.e. COMPRESSION=LZW)
# if using below this is not needed

echo "*** Creating final ortho image"
##!!gdaladdo -r average ${input_root}"/"${ortho_file}${img_file_type} 2 4 8 16 18 20  !!# NOT NEEDED DEPRECATE
gdal_translate -of COG -co NUM_THREADS=8 -co BLOCKSIZE=256 -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=IF_SAFER \
--config GDAL_CACHEMAX 80% --config GDAL_NUM_THREADS 8 ${input_root}"/"${ortho_file}${img_file_type} \
${output_root}"/"${ortho_file}${img_file_type}

echo " "
echo "*** Creating final DSM image"
gdal_translate -of COG -co NUM_THREADS=8 -co BLOCKSIZE=256 -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=IF_SAFER \
--config GDAL_CACHEMAX 80% --config GDAL_NUM_THREADS 8 ${input_root}"/"${dsm_file}${img_file_type} \
${output_root}"/"${dsm_file}${img_file_type}
# below seems to mess up the COG file
#gdal_edit.py -mo BAND_1=DSM_MSL_meters -a_nodata -9999 ${output_root}"/"${dsm_file}${img_file_type}
#

echo " "
echo "*** Creating final ortho and DSM png and kmz quicklooks"
echo "1) orthophoto"
### orthophoto  -generate from final ortho
gdal_translate -of PNG -outsize 10% 10% ${output_root}"/"${ortho_file}${img_file_type} \
${output_root}"/"${ortho_file}".png" --config GDAL_CACHEMAX 60%

gdal_translate -of KMLSUPEROVERLAY -co FORMAT=JPEG -scale 0 180 -outsize 40% 40% ${output_root}"/"${ortho_file}${img_file_type} \
${output_root}"/"${ortho_file}".kmz" --config GDAL_CACHEMAX 80%

echo " "
echo "2) DSM"
echo "*** Calculating min/max stats for:  ${dsm_file}"

zMin=`gdalinfo -mm ${output_root}"/"${dsm_file}${img_file_type} | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 1 | cut -d . -f 1`
zMax=`gdalinfo -mm ${output_root}"/"${dsm_file}${img_file_type} | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 2 | cut -d . -f 1`
gdal_translate -of KMLSUPEROVERLAY -co FORMAT=JPEG -scale ${zMin} ${zMax} -outsize 80% 80% ${output_root}"/"${dsm_file}${img_file_type} \
${output_root}"/"${dsm_file}".kmz" --config GDAL_CACHEMAX 80%

gdal_translate -of PNG -ot Byte -scale ${zMin} ${zMax} -outsize 70% 70% ${output_root}"/"${dsm_file}${img_file_type} \
${output_root}"/"${dsm_file}".png" --config GDAL_CACHEMAX 80%

echo " "
echo "*** Doing some housecleaning"
rm -v ${output_root}"/"${ortho_file}_blue${img_file_type}
rm -v ${output_root}"/"${ortho_file}_green${img_file_type}
rm -v ${output_root}"/"${ortho_file}_red${img_file_type}


##### MORE HERE
#echo " "
#echo " "
#echo "***************** Post-processing images  *****************"
#gdal_translate -of COG -co NUM_THREADS=8 -co BLOCKSIZE=256 -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=IF_SAFER \
#-b 6 --config GDAL_CACHEMAX 80% --config GDAL_NUM_THREADS 8 Generate_CHM/rgb_dsm_dem_chm_stack_for_rgbdsm_stack test_chm.tif

#####

echo " "
echo " "
echo "DONE!!"

# EOF