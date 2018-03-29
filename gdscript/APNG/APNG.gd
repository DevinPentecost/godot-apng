#Most of this information was gathered from:
#	https://en.wikipedia.org/wiki/APNG
#	https://wiki.mozilla.org/APNG_Specification
#	https://www.w3.org/TR/PNG/
extends "res://PNG/PNG.gd"


enum APNG_CHUNK_TYPES {
	acTL = 0x6163544C,
	fdAT = 0x66644154,
	fcTL = 0x6663544C,
}

static func Build_APNG_From_Sequence(output_file_path, png_sequence, width, height, include_first_in_animation=true, loops=0):
	#Returns whether it was successful
	
	#We need to build an APNG file from a whole sequence of files.
	
	#First, we need to read in the first item from the sequence
	var first_png_path = png_sequence.pop_front()
	
	#Load in all the information for it
	var first_png_information = Parse_PNG(first_png_path)
	
	#We need a few pieces of information
	var first_png_header = first_png_information[0]
	var png_signature = first_png_header[0]
	var png_header_chunk = first_png_header[1]
	var first_png_chunks = first_png_information[1]
	
	#Pop off the IEND
	var png_IEND_chunk = first_png_chunks.pop_back()
	
	#Start building all of the bytes
	var bytes = PoolByteArray()
	for byte in png_signature:
		bytes.append(byte)
	for byte in chunk_to_bytes(png_header_chunk):
		bytes.append(byte)
	
	#How many frames?
	var frame_number = 0
	var frame_count = len(png_sequence)
	if include_first_in_animation:
		frame_count += 1
		
	#Build the acTL chunk
	var acTL_chunk = build_acTL(frame_count, loops)
	for byte in chunk_to_bytes(acTL_chunk):
		bytes.append(byte)
	
	#Are we including this first one?
	if include_first_in_animation:
		#Insert a frame control
		var fcTL_chunk = build_fcTL(frame_number, width, height, 0, 0, 20, 1000, 0, 0)
		for byte in chunk_to_bytes(fcTL_chunk):
			bytes.append(byte)
	
	#Now we write the IDAT from the first PNG
	for IDAT_chunk in first_png_chunks:
		for byte in chunk_to_bytes(IDAT_chunk):
			bytes.append(byte)
	
	#Now go through the remaining images
	for png_file in png_sequence:
		
		#Create an fcTL for this frame
		var fcTL_chunk = build_fcTL(frame_number, width, height, 0, 0, 20, 1000, 0, 0)
		for byte in chunk_to_bytes(fcTL_chunk):
			bytes.append(byte)
		
		#Parse out the info from this image
		var png_information = Parse_PNG(png_file)
		var png_chunks = png_information[1]
		
		#Pop off the IEND
		png_chunks.pop_back()
		
		#Grab the remaining chunks
		for png_chunk in png_chunks:
			
			#Is this an IDAT chunk?
			var chunk_type = png_chunk[1]
			var chunk_type_value = bytes_to_int(chunk_type)
			if chunk_type_value == CHUNK_TYPES.IDAT:
				#We can use this chunk
				
				#We need to convert it to fdAT
				var frame_data_bytes = png_chunk[2]
				var fdAT_chunk = build_fdAT(frame_number, frame_data_bytes)
				for byte in chunk_to_bytes(fdAT_chunk):
					bytes.append(byte)
			else:
				print("Non-IDAT chunk. Ignoring...")
				
	#We've added all of the frames
	
	#Add the IEND
	for byte in chunk_to_bytes(png_IEND_chunk):
		bytes.append(byte)
		
	#We have all the bytes we want to write to the file
	#Let's open the file
	var output_file = File.new()
	output_file.open(output_file_path, output_file.WRITE)
	
	#Go over every byte
	for byte in bytes:
		output_file.store_8(byte)
	
	#Close the file
	output_file.close()
	print("Wrote to file: " + output_file_path)
	return true

static func build_acTL(frame_count, loop_count=0):
	#This builds an Animation Control chunk
	
	#The length of the data is always 8 bytes I'm assuming
	var data_length = 8
	var length_bytes = int_to_bytes(data_length, 4)
	
	#The opcode bytes (see enum above)
	var type_bytes = int_to_bytes(APNG_CHUNK_TYPES.acTL, 4)
	
	#The data bytes
	var data_value = (frame_count << 32) + loop_count
	var data_bytes = int_to_bytes(data_value, data_length)
	
	#Calculate the CRC
	
	#Get all the bytes
	var bytes = []
	var byte_count = 0
	for byte_array in [length_bytes, type_bytes, data_bytes]:
		for byte in byte_array:
			byte_count += 1
			bytes.append(byte)
			
	#Now calculate the CRC
	var crc_value = calculate_crc(bytes, byte_count)
	var crc_bytes = int_to_bytes(crc_value, 4)
	
	#We have our whole chunk
	print("Built acTL for frame " + str(frame_count))
	return [length_bytes, type_bytes, data_bytes, crc_bytes]

static func build_fcTL(frame_number, width, height, x_offset, y_offset, delay_numerator, delay_denominator, dispose_operation=0, blend_operation=0):
	
	#The data is always 26 bytes long
	var data_length = 26
	var length_bytes = int_to_bytes(data_length, 4)
	
	#The opcode (see enum)
	var type_bytes = int_to_bytes(APNG_CHUNK_TYPES.fcTL, 4)
	
	#The data bytes, gonna be tricky
	var data_bytes = PoolByteArray()
	for parameter in [[frame_number, 4], [width, 4], [height, 4], [x_offset, 4], [y_offset, 4], [delay_numerator, 2], [delay_denominator, 2], [dispose_operation, 1], [blend_operation, 1]]:
		var value = parameter[0]
		var size = parameter[1]
		for byte in int_to_bytes(value, size):
			data_bytes.append(byte)
	
	#Calculate the CRC
	#Get all the bytes
	var bytes = []
	var byte_count = 0
	for byte_array in [length_bytes, type_bytes, data_bytes]:
		for byte in byte_array:
			++byte_count
			bytes.append(byte)
			
	#Now calculate the CRC
	var crc_value = calculate_crc(bytes, byte_count)
	var crc_bytes = int_to_bytes(crc_value, 4)
	
	#We have our whole chunk
	print("Built fcTL for frame " + str(frame_number))
	return [length_bytes, type_bytes, data_bytes, crc_bytes]
	
static func build_fdAT(frame_number, frame_data_bytes):
	
	#The length is always one integer more than the data
	var data_length = len(frame_data_bytes) + 4
	var length_bytes = int_to_bytes(data_length, 4)
	
	#The type (see enum)
	var type_bytes = int_to_bytes(APNG_CHUNK_TYPES.fdAT, 4)
	
	#The data bytes
	var data_bytes = int_to_bytes(frame_number, 1)
	for byte in frame_data_bytes:
		data_bytes.append(byte)
	
	#Calculate the CRC
	#Get all the bytes
	var bytes = []
	var byte_count = 0
	for byte_array in [length_bytes, type_bytes, data_bytes]:
		for byte in byte_array:
			++byte_count
			bytes.append(byte)
			
	#Now calculate the CRC
	var crc_value = calculate_crc(bytes, byte_count)
	var crc_bytes = int_to_bytes(crc_value, 4)
	
	#We have our whole chunk
	print("Built fdAT for frame " + str(frame_number))
	return [length_bytes, type_bytes, data_bytes, crc_bytes]

