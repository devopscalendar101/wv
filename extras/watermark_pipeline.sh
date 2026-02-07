#!/usr/bin/env bash

[[ $# -lt 2 ]] && { echo "Enter Bucket_Name and Object"; exit 1; }
pwd_path="$PWD"
bucket_original="${VIDEO_BUCKET_ORIGINAL:-class-recordings-itdefined-original}"
batch="$2"
wm_path='/home/drive/watermark'

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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
delete_attendance="${13}"
delete_class="${14}"
s3_delete_watermark="${15}"
use_s3_original="${16}"
vimeo_access_token="${17}"
vimeo_client_id="${18}"
vimeo_client_secret="${19}"
vemio_delete="${20}"

base_path="${HOME}/.tmp"
mkdir -p "$base_path"
cd "$base_path"

[[ -d "${base_path}/${batch_name}" ]] || mkdir -p "${base_path}/${batch_name}"
mkdir -p "${base_path}/${batch_name}/output"

# Parse date (YYYYMMDD to YYYY-MM-DD)
year=${class_date:0:4}
month=${class_date:4:2}
day=${class_date:6:2}
class_formated_date="${year}-${month}-${day}"
original_video_dir="${base_path}/${batch_name}"
original_video_full="${base_path}/${batch_name}/${class_date}.mp4"
watermarked_video="${base_path}/${batch_name}/output/${class_date}.mp4"
original_video_base="${batch_name}/${class_date}.mp4"

log_stamp="${batch_name}_${class_formated_date}"
export PATH="$pwd_path/extras:${PATH}"

# ─────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────

get_file_size() {
	local file="$1"
	if [[ -f "$file" ]]; then
		local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
		if [[ -n "$size" ]]; then
			numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || {
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

# Check if file exists in S3
s3_exists() {
	local bucket="$1" key="$2"
	[[ "$(s3_tool -m check -b "$bucket" -k "$key")" == 'true' ]]
}

log_step() { echo -e "    ${CYAN}$1${NC}"; }
log_ok()   { echo -e "            --> ${GREEN}$1${NC}"; }
log_skip() { echo -e "            --> ${YELLOW}SKIP: $1${NC}"; }
log_warn() { echo -e "            --> ${YELLOW}WARNING: $1${NC}"; }
log_err()  { echo -e "            --> ${RED}ERROR: $1${NC}"; }
log_info() { echo -e "            --> $1"; }

# ─────────────────────────────────────────────
# DB Functions
# ─────────────────────────────────────────────

update_class() {
	local s3_success="$1"
	local vimeo_success="$2"
	local vimeo_video_id="$3"
	local video_source=""

	export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD

	if [[ "$vimeo_success" == "true" ]]; then
		video_source="vimeo"
	elif [[ "$s3_success" == "true" ]]; then
		video_source="aws_s3"
	fi

	if [[ "$delete_class" == 'true' ]]; then
		log_info "Deleting existing class record (${log_stamp})"
		/usr/bin/psql -qtAX -c "DELETE FROM public.course_trainingmaterial WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date'";
	fi

	local existing=$(/usr/bin/psql -qtAX -c "SELECT topic FROM public.course_trainingmaterial WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date'")

	if [[ -n "$existing" ]]; then
		# Class exists - update if we have video
		if [[ -n "$video_source" ]]; then
			if [[ -n "$vimeo_video_id" ]] && [[ "$vimeo_video_id" != "NULL" ]]; then
				/usr/bin/psql -q -c "UPDATE public.course_trainingmaterial SET video_source_from='$video_source', vimeo_video_id='$vimeo_video_id' WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date';"
			else
				/usr/bin/psql -q -c "UPDATE public.course_trainingmaterial SET video_source_from='$video_source' WHERE course_id='$course_id' AND webinar_id='$itd_webinar_id' AND date_of_training='$class_formated_date';"
			fi
			log_ok "Updated class Notes video source to $video_source (${log_stamp})"
		else
			log_skip "Class exists, no video update (${log_stamp})"
		fi
	else
		# Insert new record
		if [[ -n "$vimeo_video_id" ]] && [[ "$vimeo_video_id" != "NULL" ]]; then
			/usr/bin/psql -q -c "INSERT INTO public.course_trainingmaterial(topic, webinar_id, course_id, recording_link, date_of_training, status, parent_topic, material_type, video_source_from, vimeo_video_id) VALUES ('$topic', '$itd_webinar_id', $course_id, '${class_date}.mp4', '$class_formated_date', '', '$parent_topic', 'class_notes', '$video_source', '$vimeo_video_id');"
		else
			/usr/bin/psql -q -c "INSERT INTO public.course_trainingmaterial(topic, webinar_id, course_id, recording_link, date_of_training, status, parent_topic, material_type, video_source_from) VALUES ('$topic', '$itd_webinar_id', $course_id, '${class_date}.mp4', '$class_formated_date', '', '$parent_topic', 'class_notes', '${video_source:-NULL}');"
		fi
		log_ok "Created class Notes (${log_stamp})"
	fi
}

update_attendance() {
	export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD

	if [[ "$delete_attendance" == 'true' ]]; then
		log_info "Deleting existing attendance (${log_stamp})"
		/usr/bin/psql -qtAX -c "DELETE FROM public.course_courseattendance WHERE batch_id='$batch_id' AND date='$class_formated_date'";
	fi
	if [[ -n "$(/usr/bin/psql -qtAX -c "SELECT * FROM public.course_courseattendance WHERE batch_id='$batch_id' AND date='$class_formated_date'")" ]]; then
		log_skip "Attendance already exists (${log_stamp})"
	else
		zoom_attendance $batch_name $webinar_id $zoom_account $itd_webinar_id "$webinar_email" "$class_formated_date"
	fi
}

# ─────────────────────────────────────────────
# MAIN PIPELINE (Idempotent - safe to re-run)
# ─────────────────────────────────────────────

convert_upload() {
	local s3_upload_success="false"
	local vimeo_upload_success="false"
	local vimeo_video_id="NULL"
	local has_original="false"
	local has_watermark="false"

	# ── PRE-CHECK: What already exists? ──
	echo ""
	log_step "PRE-CHECK: Scanning existing assets..."

	if s3_exists "$bucket_original" "$original_video_base"; then
		has_original="true"
		log_ok "Original video EXISTS in S3: $bucket_original/$original_video_base"
	else
		log_info "Original video NOT in S3: $bucket_original/$original_video_base"
	fi

	if s3_exists "$bucket_name" "$original_video_base"; then
		has_watermark="true"
		log_ok "Watermarked video EXISTS in S3: $bucket_name/$original_video_base"
	else
		log_info "Watermarked video NOT in S3: $bucket_name/$original_video_base"
	fi

	# Check Vimeo (pass the expected filename so vemio_upload can match it)
	local has_vimeo="false"
	local vimeo_check_output=$(vemio_upload "$batch_name" "${class_date}.mp4" "$vimeo_access_token" "$vimeo_client_id" "$vimeo_client_secret" "false" 2>&1 || true)
	if echo "$vimeo_check_output" | grep -qi "already exists" 2>/dev/null; then
		has_vimeo="true"
		vimeo_video_id=$(echo "$vimeo_check_output" | grep -oP '(?<=Vimeo Server: )\d+' | head -n1)
		log_ok "Video EXISTS in Vimeo (ID: ${vimeo_video_id:-unknown})"
	else
		log_info "Video NOT in Vimeo"
	fi

	echo ""

	# ══════════════════════════════════════════
	# STEP 1: Get original video (Zoom / S3 / Local upload)
	# ══════════════════════════════════════════

	# Handle force-delete flags first
	if [[ "$s3_delete_original" == "true" ]] && [[ "$has_original" == "true" ]]; then
		log_step "STEP_1a: Force-deleting original from S3 (s3_delete_original=true)"
		s3_tool -m delete -b "$bucket_original" -k "$original_video_base" | sed 's/^/            --> /'
		has_original="false"
	fi

	log_step "STEP_1: Getting original video (${log_stamp})"

	if [[ "$has_original" == "true" ]] && [[ "$use_s3_original" != "true" ]]; then
		# Original in S3, no need to download from Zoom
		log_skip "Original already in S3 - skipping Zoom download"
		# Download from S3 only if we need local copy for watermarking
		if [[ "$has_watermark" == "false" ]] && [[ ! -f "$original_video_full" ]]; then
			log_info "Downloading original from S3 for watermarking..."
			s3_tool -m download -b "$bucket_original" -k "$original_video_base" --path "$original_video_dir" > /dev/null 2>&1
			[[ -f "$original_video_full" ]] && log_ok "Downloaded: $(get_file_size "$original_video_full")"
		fi
	elif [[ "$use_s3_original" == "true" ]]; then
		# Explicit: download from S3 original
		log_info "Downloading from S3 original bucket..."
		s3_tool -m download -b "$bucket_original" -k "$original_video_base" --path "$original_video_dir" > /dev/null 2>&1
		if [[ -f "$original_video_full" ]]; then
			log_ok "Downloaded from S3: $(get_file_size "$original_video_full")"
		else
			log_err "Video not found in S3: $bucket_original/$original_video_base"
			return 1
		fi
	else
		# Download from Zoom
		log_info "Downloading from Zoom..."
		args=("$batch_name" "$webinar_id" "$zoom_account" "$class_date")
		echo "$(zoomd "${args[@]}" | sed 's/^/            --> /')"
		if [[ -f "$original_video_full" ]]; then
			log_ok "Downloaded from Zoom: $(get_file_size "$original_video_full")"
		else
			log_warn "No video available from Zoom (no class taken or still processing)"
			return 2
		fi
	fi

	# ══════════════════════════════════════════
	# STEP 2: Upload original to S3 backup
	# ══════════════════════════════════════════

	log_step "STEP_2: Upload original to S3 backup (${log_stamp})"

	if [[ "$has_original" == "true" ]] && [[ "$s3_delete_original" != "true" ]]; then
		log_skip "Original already in S3 backup"
	elif [[ -f "$original_video_full" ]]; then
		s3_tool -m upload -b "$bucket_original" -k "$original_video_base" --path "$original_video_full" | sed 's/^/            --> /'
		log_ok "Uploaded original to S3 backup"
		has_original="true"
	else
		log_skip "No local original to upload"
	fi

	# ══════════════════════════════════════════
	# STEP 3: Apply watermark
	# ══════════════════════════════════════════

	# Handle force-delete watermark flag
	if [[ "$s3_delete_watermark" == "true" ]] && [[ "$has_watermark" == "true" ]]; then
		log_step "STEP_3a: Force-deleting watermark from S3 (s3_delete_watermark=true)"
		s3_tool -m delete -b "$bucket_name" -k "$original_video_base" | sed 's/^/            --> /'
		has_watermark="false"
	fi

	log_step "STEP_3: Apply watermark (${log_stamp})"

	if [[ "$has_watermark" == "true" ]]; then
		log_skip "Watermarked video already in S3"
		s3_upload_success="true"
		# Download watermarked for Vimeo upload if needed
		if [[ "$has_vimeo" == "false" ]] || [[ "$vemio_delete" == "true" ]]; then
			if [[ ! -f "$watermarked_video" ]]; then
				log_info "Downloading watermarked from S3 for Vimeo upload..."
				s3_tool -m download -b "$bucket_name" -k "$original_video_base" --path "$(dirname "$watermarked_video")" > /dev/null 2>&1
				[[ -f "$watermarked_video" ]] && log_ok "Downloaded: $(get_file_size "$watermarked_video")"
			fi
		fi
	elif [[ -f "$original_video_full" ]]; then
		log_info "Applying watermark..."
		watermark "$original_video_full" "$watermarked_video" | sed 's/^/            --> /'
		if [[ -f "$watermarked_video" ]]; then
			log_ok "Watermark applied: $(get_file_size "$watermarked_video")"
		else
			log_err "Watermarking failed"
			return 1
		fi
	else
		log_err "No source video available for watermarking"
		return 1
	fi

	# ══════════════════════════════════════════
	# STEP 4: Upload watermarked to S3
	# ══════════════════════════════════════════

	log_step "STEP_4: Upload watermarked to S3 (${log_stamp})"

	if [[ "$s3_upload_success" == "true" ]]; then
		log_skip "Already in S3 watermark bucket"
	elif [[ -f "$watermarked_video" ]]; then
		if s3_tool -m upload -b "$bucket_name" -k "$original_video_base" --path "$watermarked_video" > /dev/null 2>&1; then
			log_ok "Uploaded watermarked to S3"
			s3_upload_success="true"
		else
			log_err "S3 watermark upload failed"
		fi
	else
		log_err "No watermarked video to upload"
	fi

	# ══════════════════════════════════════════
	# STEP 5: Upload to Vimeo
	# ══════════════════════════════════════════

	# Handle force-delete Vimeo flag
	if [[ "$vemio_delete" == "true" ]]; then
		has_vimeo="false"
	fi

	log_step "STEP_5: Upload to Vimeo (${log_stamp})"

	if [[ "$has_vimeo" == "true" ]] && [[ "$vemio_delete" != "true" ]]; then
		log_skip "Video already in Vimeo (ID: ${vimeo_video_id:-unknown})"
		vimeo_upload_success="true"
	elif [[ -f "$watermarked_video" ]]; then
		local vimeo_output=$(vemio_upload "$batch_name" "$watermarked_video" "$vimeo_access_token" "$vimeo_client_id" "$vimeo_client_secret" "$vemio_delete" 2>&1)
		echo "$vimeo_output" | sed 's/^/            /'
		if echo "$vimeo_output" | grep -q "Video uploaded to Vimeo Server\|Video already exists in Vimeo Server" 2>/dev/null; then
			vimeo_upload_success="true"
			vimeo_video_id=$(echo "$vimeo_output" | grep -oP '(?<=Vimeo Server: )\d+' | head -n1)
			[[ -z "$vimeo_video_id" ]] && vimeo_video_id="NULL"
			log_ok "Vimeo upload success (ID: $vimeo_video_id)"
		else
			log_err "Vimeo upload failed"
		fi
	else
		log_err "No watermarked video for Vimeo upload"
	fi

	# ══════════════════════════════════════════
	# STEP 6: Update database
	# ══════════════════════════════════════════

	log_step "STEP_6: Update database (${log_stamp})"
	update_class "$s3_upload_success" "$vimeo_upload_success" "$vimeo_video_id"

	# ══════════════════════════════════════════
	# STEP 7: Update attendance
	# ══════════════════════════════════════════

	log_step "STEP_7: Update attendance (${log_stamp})"
	update_attendance

	echo -e "-----------------------------------------------------------------------------------------"
}

echo -e "\n─────────────────────────  ${batch_name}  ${class_formated_date} ──────────────────────────"

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
	S3_DELETE_ORIGINAL: $s3_delete_original
	S3_DELETE_WATERMARK: $s3_delete_watermark
	VEMIO_DELETE: $vemio_delete
	DELETE_ATTENDANCE: $delete_attendance
	DELETE_CLASS: $delete_class"

convert_upload
pipeline_rc=$?

if [[ $pipeline_rc -eq 2 ]]; then
	echo -e "\n${YELLOW}⚠️  RESULT: NO VIDEO — No class or Zoom still processing (${log_stamp})${NC}"
	exit 2
elif [[ $pipeline_rc -ne 0 ]]; then
	echo -e "\n${RED}❌ RESULT: PIPELINE FAILED (${log_stamp})${NC}"
	exit 1
else
	echo -e "\n${GREEN}✅ RESULT: PIPELINE COMPLETE (${log_stamp})${NC}"
	exit 0
fi
