#!/usr/bin/env bash

[[ $# -lt 2 ]] && { echo "Enter Bucket_Name and Object"; exit 1; }
pwd_path="$PWD"
bucket_original="${VIDEO_BUCKET_ORIGINAL:-class-recordings-itdefined-original}"
batch="$2"
wm_path='/home/drive/watermark'

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

bucket_name="$1"
batch_name="$2"
itd_webinar_id="$3"
zoom_account="$4"
topic="$5"
course_id="$6"
batch_id="$7"
parent_topic="$8"
webinar_id="$9"
webinar_email="${10}"
class_date="${11}"
s3_delete_original="${12}"
delete_local_videos="${13}"
delete_attendance="${14}"
clean_local="${15}"
delete_class="${16}"
s3_delete_watermark="${17}"
use_s3_original="${18}"
vimeo_access_token="${19}"
vimeo_client_id="${20}"
vimeo_client_secret="${21}"
vemio_delete="${22}"

base_path="${HOME}/.tmp"; cd "$base_path"
# s3l "$bucket_name" "$batch" '.mp4' | grep -vi 'original'
[[ -d "${base_path}/${batch}" ]] || mkdir -p "${base_path}/${batch}"

# Parse date for macOS (YYYYMMDD to YYYY-MM-DD)
year=${class_date:0:4}
month=${class_date:4:2}
day=${class_date:6:2}
class_formated_date="${year}-${month}-${day}"
original_video_dir="${base_path}/${batch_name}"
original_video_full="${base_path}/${batch_name}/${class_date}.mp4"
watermarked_video="${base_path}/${batch_name}/output/${class_date}.mp4"
original_video_base="${batch_name}/${class_date}.mp4"

video_source=""

log_stamp="${batch_name}_${class_formated_date}"
export PATH="$pwd_path/extras:${PATH}"

# Function to get human-readable file size
get_file_size() {
	local file="$1"
	if [[ -f "$file" ]]; then
		local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
		if [[ -n "$size" ]]; then
			numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || {
				# Fallback if numfmt is not available
				if (( size >= 1073741824 )); then
					echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}")GiB"
				elif (( size >= 1048576 )); then
					echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}")MiB"
				elif (( size >= 1024 )); then
					echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}")KiB"
				else
					echo "${size}B"
				fi
			}
		fi
	fi
}

update_class() {
	local s3_success="$1"
	local vimeo_success="$2"
	local vimeo_video_id="$3"
	local video_source=""
	
	# Ensure database environment variables are set
	export PGHOST="${PGHOST}"
	export PGPORT="${PGPORT}"
	export PGDATABASE="${PGDATABASE}"
	export PGUSER="${PGUSER}"
	export PGPASSWORD="${PGPASSWORD}"
	
	# Determine video_source_from based on upload success
	if [[ "$vimeo_success" == "true" ]]; then
		video_source="vimeo"
	elif [[ "$s3_success" == "true" ]]; then
		video_source="aws_s3"
	else
		video_source="NULL"
	fi
	
	if [[ "$delete_class" == 'true' ]]; then  
		echo "Deleting exisiting class in ITDefined  (${log_stamp})"
		/usr/bin/psql -qtAX -c "DELETE FROM public.course_trainingmaterial WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date'";
	fi
	
	if [[ -n "$(/usr/bin/psql -qtAX -c "SELECT topic FROM public.course_trainingmaterial WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date'")" ]]; then
		# Class exists - only update if we have a new video
		if [[ "$s3_success" == "true" ]] || [[ "$vimeo_success" == "true" ]]; then
			if [[ "$video_source" == "NULL" ]]; then
				/usr/bin/psql -q -c "UPDATE public.course_trainingmaterial SET video_source_from=NULL WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date';"
			else
				# Update video_source_from and vimeo_video_id
				if [[ -n "$vimeo_video_id" ]] && [[ "$vimeo_video_id" != "NULL" ]]; then
					/usr/bin/psql -q -c "UPDATE public.course_trainingmaterial SET video_source_from='$video_source', vimeo_video_id='$vimeo_video_id' WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date';"
				else
					/usr/bin/psql -q -c "UPDATE public.course_trainingmaterial SET video_source_from='$video_source' WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date';"
				fi
			fi
			# Fetch parent_topic from DB to confirm update
			db_parent_topic=$(/usr/bin/psql -qtAX -c "SELECT parent_topic FROM public.course_trainingmaterial WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date'")
			echo -e "${GREEN}Updated class Notes video source to $video_source in itdefined.org (${log_stamp})${NC}"
			[[ -n "$vimeo_video_id" ]] && [[ "$vimeo_video_id" != "NULL" ]] && echo -e "Vimeo Video ID: $vimeo_video_id"
			echo -e "Topic: $db_parent_topic"
		else
			echo -e "${GREEN}Class Notes already exists, no video update (${log_stamp})${NC}"
		fi
    else
		# Class doesn't exist - insert new record
		if [[ "$video_source" == "NULL" ]]; then
			/usr/bin/psql -q -c "INSERT INTO public.course_trainingmaterial(topic, webinar_id, course_id, recording_link, date_of_training, status, parent_topic, material_type, video_source_from) VALUES ('$topic', '$itd_webinar_id', $course_id, '${class_date}.mp4', '$class_formated_date', '', '$parent_topic', 'class_notes', NULL);"
		else
			# Insert with vimeo_video_id if available
			if [[ -n "$vimeo_video_id" ]] && [[ "$vimeo_video_id" != "NULL" ]]; then
				/usr/bin/psql -q -c "INSERT INTO public.course_trainingmaterial(topic, webinar_id, course_id, recording_link, date_of_training, status, parent_topic, material_type, video_source_from, vimeo_video_id) VALUES ('$topic', '$itd_webinar_id', $course_id, '${class_date}.mp4', '$class_formated_date', '', '$parent_topic', 'class_notes', '$video_source', '$vimeo_video_id');"
			else
				/usr/bin/psql -q -c "INSERT INTO public.course_trainingmaterial(topic, webinar_id, course_id, recording_link, date_of_training, status, parent_topic, material_type, video_source_from) VALUES ('$topic', '$itd_webinar_id', $course_id, '${class_date}.mp4', '$class_formated_date', '', '$parent_topic', 'class_notes', '$video_source');"
			fi
		fi
		# Fetch parent_topic from DB to confirm creation
		db_parent_topic=$(/usr/bin/psql -qtAX -c "SELECT parent_topic FROM public.course_trainingmaterial WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date'")
		echo -e "            --> ${GREEN}Created class Notes in itdefined.org with video source: $video_source (${log_stamp})${NC}"
		[[ -n "$vimeo_video_id" ]] && [[ "$vimeo_video_id" != "NULL" ]] && echo -e "            --> Vimeo Video ID: $vimeo_video_id"
		echo -e "            --> Topic: $db_parent_topic"
    fi
}

update_attendance() {
	# Ensure database environment variables are set
	export PGHOST="${PGHOST}"
	export PGPORT="${PGPORT}"
	export PGDATABASE="${PGDATABASE}"
	export PGUSER="${PGUSER}"
	export PGPASSWORD="${PGPASSWORD}"
	
	if [[ "$delete_attendance" == 'true' ]]; then  
		echo "Deleting exisiting attendance in ITDefined  (${log_stamp})" | sed 's/^/            --> /'
		/usr/bin/psql -qtAX -c "DELETE FROM public.course_courseattendance WHERE batch_id='$batch_id' AND date='$class_formated_date'";
	fi 
	if [[ -n "$(/usr/bin/psql -qtAX -c "SELECT * FROM public.course_courseattendance WHERE batch_id='$batch_id' AND date='$class_formated_date'")" ]]; then
        echo "            --> Class Attendance already exists in itdefined.org  (${log_stamp})"
    else
        zoom_attendance $batch_name $webinar_id $zoom_account $itd_webinar_id "$webinar_email" "$class_formated_date"
    fi
}

convert_upload() {
	
	# all_files="$($pwd_path/scripts/s3l "$bucket_name" "$batch_name" '.mp4')"

    if [[ "$use_s3_original" == "true" ]]; then
		echo "    STEP_1: Downloading Video from S3: (${log_stamp})"
		[[ "$delete_local_videos" == "true" ]] && [[ -f "$original_video_full" ]] && rm -f "$original_video_full"
        # Download video from S3 using s3_tool
        s3_tool -m download -b "$bucket_original" -k "$original_video_base" --path "$original_video_dir"
		if [[ ! -f "$original_video_full" ]]; then
			echo -e "            --> ${RED}ERROR: Video not found in S3 at $original_video_full. Skipping watermark and upload steps.${NC}"
			return 0
		fi
		original_size=$(get_file_size "$original_video_full")
		echo -e "            --> ${GREEN}Downloaded video from S3: $bucket_original/$original_video_base (size: $original_size) (${log_stamp})${NC}"

    else
		echo "    STEP_1: Downloading Video from Zoom: (${log_stamp})"
        # If s3_delete_original is true, delete from original bucket
        if [[ "$s3_delete_original" == "true" ]]; then
            echo "            --> Deleting video from original bucket: $bucket_original/$original_video_base (${log_stamp})"
            s3_tool -m delete -b "$bucket_original" -k "$original_video_base"
        fi
        # Download video from zoom by date
        args=("$batch_name" "$webinar_id" "$zoom_account" "$class_date")
        [[ "$delete_local_videos" == "true" ]] && args+=("$delete_local_videos")
        echo "$(zoomd "${args[@]}" | sed 's/^/            --> /')"
		# Get original video size after download
		if [[ -f "$original_video_full" ]]; then
			original_size=$(get_file_size "$original_video_full")
			echo -e "            --> ${GREEN}Original video size: $original_size${NC}"
		fi
    fi

    # # If s3_delete_watermark is true, delete from watermark bucket
    # if [[ "$s3_delete_watermark" == "true" ]]; then
    #     echo "Deleting video from watermark bucket: $bucket_name/$original_video_base"
    #     s3_tool -m delete -b "$bucket_name" -k "$original_video_base" | sed 's/^/            --> /'
    # fi

	echo "    STEP_2: Uploading original zoom video to backup s3 bucket:  (${log_stamp})"
		if [[ "$use_s3_original" == 'true' ]]; then 
			echo "            --> Skiping upload as Using original video from S3  (${log_stamp})" | sed 's/^/            --> /'
		else 
			[[ "$s3_delete_original" == 'true' ]] && { s3_tool -m delete -b "$bucket_original" -k "$original_video_base" | sed 's/^/            --> /'; }
			echo "$(s3_tool -m upload -b "$bucket_original" -k "$original_video_base" --path "$original_video_full" | sed 's/^/            --> /')" 
		fi
	echo "    STEP_3: Applying watermark to Video:  (${log_stamp})"
		[[ "$delete_local_videos" == "true" ]] && rm -f "$watermarked_video"
		[[ "$s3_delete_watermark" == 'true' ]] && { s3_tool -m delete -b "$bucket_name" -k "$original_video_base" | sed 's/^/            --> /'; }
		
		if [[ "$(s3_tool -m check -b "$bucket_name" -k "$original_video_base")" == 'true' ]]; then
			echo -e "            --> ${GREEN}Watermarked video already in s3: ${bucket_name} -> ${original_video_base}${NC}" 
			# Download watermarked video from S3 if it doesn't exist locally
			if [[ ! -f "$watermarked_video" ]]; then
				mkdir -p "$(dirname "$watermarked_video")"
				if [[ "$(s3_tool -m download -b "$bucket_name" -k "$original_video_base" --path "$(dirname "$watermarked_video")")" == 'true' ]]; then
					watermarked_size=$(get_file_size "$watermarked_video")
					echo -e "            --> ${GREEN}Downloaded watermarked video from S3 for Vimeo upload (size: $watermarked_size)${NC}"
					video_source="aws_s3"
				fi
			else 
				video_source="aws_s3"
				watermarked_size=$(get_file_size "$watermarked_video")
				echo -e "            --> ${GREEN}Watermarked video found locally (size: $watermarked_size)${NC}"
			fi
		else 
			(watermark "$original_video_full" "$watermarked_video" | sed 's/^/            --> /')
			if [[ -f "$watermarked_video" ]]; then
				watermarked_size=$(get_file_size "$watermarked_video")
				echo -e "            --> ${GREEN}Watermark applied successfully (size: $watermarked_size)${NC}"
			fi
		fi 

	if [[ -f "$watermarked_video" ]]; then
		# Track upload success/failure
		s3_upload_success="false"
		vimeo_upload_success="false"
		
		echo "    STEP_4: Uploading watermark video to s3:  (${log_stamp})"
		if [[ "$(s3_tool -m check -b "$bucket_name" -k "$original_video_base")" == 'true' ]]; then
			echo -e "            --> ${GREEN}Skipping S3 upload - watermarked video already exists in s3${NC}"
			s3_upload_success="true"
		else
			if s3_tool -m upload -b "$bucket_name" -k "$original_video_base" --path "$watermarked_video" > /dev/null 2>&1; then
				echo -e "            --> ${GREEN}S3 upload successful${NC}"
				s3_upload_success="true"
			else
				echo -e "            --> ${RED}S3 upload failed${NC}"
				s3_upload_success="false"
			fi
		fi
		
		echo "    STEP_5: Uploading watermark video to vemio server:  (${log_stamp})"
		vimeo_output=$(vemio_upload "$batch_name" "$watermarked_video" "$vimeo_access_token" "$vimeo_client_id" "$vimeo_client_secret" "$vemio_delete" 2>&1)
		echo "$vimeo_output" | sed 's/^/            /'
		
		# Extract Vimeo video ID from output
		vimeo_video_id="NULL"
		if echo "$vimeo_output" | grep -q "Video uploaded to Vimeo Server\|Video already exists in Vimeo Server" &>/dev/null; then
			vimeo_upload_success="true"
			# Extract video ID from output (format: "Video uploaded to Vimeo Server: 123456789 filename.mp4")
			vimeo_video_id=$(echo "$vimeo_output" | grep -oP '(?<=Vimeo Server: )\d+' | head -n1)
			[[ -z "$vimeo_video_id" ]] && vimeo_video_id="NULL"
		else
			vimeo_upload_success="false"
		fi
		
		echo "    STEP_6: Updating notes to itdefined.org:  (${log_stamp})"
		update_class "$s3_upload_success" "$vimeo_upload_success" "$vimeo_video_id" | sed 's/^/            --> /'
	else
		echo -e "            --> ${RED}ERROR: Watermarked video not found at $watermarked_video. Skipping upload steps.${NC}"
	fi

	# echo "    STEP_6: Updating class attendance in itdefined.org ......"
	# update_attendance 

	echo -e "-----------------------------------------------------------------------------------------"
}

echo -e "\n-------------------------  ${batch_name}  ${class_formated_date} ------------------------------"

echo "    CONFIGURATIONS: 
	BUCKET_NAME: $bucket_name
	BATCH_NAME: $batch_name
	ITD_WEBINAR_ID: $itd_webinar_id
	ZOOM_ACCOUNT: $zoom_account
	TOPIC: $topic
	COURSE_ID: $course_id
	BATCH_ID: $batch_id
	PARENT_TOPIC: $parent_topic
	WEBINAR_ID: $webinar_id
	WEBINAR_EMAIL: $webinar_email
	CLASS_DATE: $class_date
	S3_DELETE: $s3_delete
	DELETE_LOCAL_VIDEOS: $delete_local_videos
	DELETE_ATTENDANCE: $delete_attendance"

convert_upload
