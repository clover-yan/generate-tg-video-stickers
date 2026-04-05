#!/bin/bash

max_size=262144
input_dir="gifs"
output_dir="output"

function compress_gif() {
	ffmpeg -y -i "$1" -c:v libvpx-vp9 -vf "scale=512:512" -crf "$3" -b:v 0 -deadline best -pix_fmt yuva420p -an "$2" 2>/dev/null
}

function get_file_size() {
	stat -c%s "$1"
}

if ! command -v ffmpeg &> /dev/null; then
	echo "ffmpeg could not be found. Please install ffmpeg to use this script."
	exit 1
fi

mkdir -p "$output_dir"

for input_file in "${input_dir}"/*.gif; do
	[ -e "$input_file" ] || continue
	
	base_name="$(basename "${input_file%.*}")"
	output_file="${output_dir}/output.webm"
	output_file_final="${output_dir}/${base_name}.webm"
	
	crf=30
	echo "Processing: $input_file ..."

	echo "$input_file" "$output_file" $crf
	compress_gif "$input_file" "$output_file" $crf
	current_size=$(get_file_size "$output_file")

	if [ "$current_size" -le "$max_size" ]; then
		echo "  [INFO] $output_file: CRF=$crf, Size=${current_size} bytes (under max size, trying lower CRF)"
		mv "$output_file" "$output_file_final"
		crf=$((crf - 1))
		while [ $crf -ge 0 ]; do
			compress_gif "$input_file" "$output_file" $crf
			current_size=$(get_file_size "$output_file")
			if [ "$current_size" -ge "$max_size" ]; then
				echo "    [INFO] $output_file: CRF=$crf, Size=${current_size} bytes (too large, reverting to previous CRF)"
				rm "$output_file"
				break
			else
				echo "    [INFO] $output_file: CRF=$crf, Size=${current_size} bytes (smaller than max size, trying lower CRF)"
				mv "$output_file" "$output_file_final"
				crf=$((crf - 1))
			fi
		done
		crf=$((crf + 1))
	elif [ "$current_size" -gt "$max_size" ]; then
		echo "  [INFO] $output_file: CRF=$crf, Size=${current_size} bytes (too large, increasing CRF)"
		while [ $crf -le 63 ] && [ "$current_size" -gt "$max_size" ]; do
			crf=$((crf + 1))
			compress_gif "$input_file" "$output_file" $crf
			current_size=$(get_file_size "$output_file")
			echo "    [INFO] $output_file: CRF=$crf, Size=${current_size} bytes"
		done
		mv "$output_file" "$output_file_final"
	fi

	echo "  [SUCCESS] Final output: $output_file_final, CRF=$crf, Size=$(get_file_size "$output_file_final") bytes"
done
