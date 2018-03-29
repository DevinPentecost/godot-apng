#Most of this information was gathered from:
#	https://en.wikipedia.org/wiki/APNG
#	https://wiki.mozilla.org/APNG_Specification
#	https://www.w3.org/TR/PNG/

const PNG_SIGNATURE = 0x89504E470D0A1A0A
enum CHUNK_TYPES {
	IHDR = 0x49484452,
	IDAT = 0x49444154,
	IEND = 0x49454E44
}
const crc_table = []

static func Parse_PNG(png_file_path):
	#Parses out an entire PNG file
	var png_file = File.new()
	
	#First, check the file exists
	if not png_file.file_exists(png_file_path):
		print("File does not exist! " + png_file_path)
		return null
	
	#Open the file
	png_file.open(png_file_path, png_file.READ)
	
	#Get the header
	var png_header = get_header(png_file)
	
	#While there is still file left to handle
	var png_chunks = []
	while not png_file.eof_reached():
		#Get more chunks
		var chunk = get_next_chunk(png_file)
		png_chunks.append(chunk)
		
		#Did we get an END chunk?
		var chunk_type = chunk[1]
		var chunk_type_value = bytes_to_int(chunk_type)
		if chunk_type_value == CHUNK_TYPES.IEND:
			#We're done
			print("Found IEND chunk, no longer parsing!")
			break
	
	#Close the file
	png_file.close()
		
	#We have successfully extracted everything from this file.
	return [png_header, png_chunks]
	

static func get_header(png_file):
	#Takes an already open PNG file and extracts the header from it
	#This is the PNG signature AND IHDR chunk
	#This function will move the file handler forward
	
	#Get the signature (8 bytes)
	var signature_bytes = []
	for byte in range(8):
		signature_bytes.append(png_file.get_8())
		
	#Does this match the expected signature?
	var signature_value = bytes_to_int(signature_bytes)
	if signature_value != PNG_SIGNATURE:
		print("Did not get PNG signature at start of file... aborting!")
		return null
	
	#Get the IHDR bytes (25 bytes)
	var header_bytes = get_next_chunk(png_file)
		
	#Was this actually the IHDR?
	var header_type_bytes = header_bytes[1]
	var header_value = bytes_to_int(header_type_bytes)
	if header_value != CHUNK_TYPES.IHDR:
		#TODO: Handle this case! Maybe they are out of order?
		print("Did not get IHRD after PNG signature...")
	
	#Return the header
	return [signature_bytes, header_bytes]
	
static func get_next_chunk(png_file):
	#Takes an already open PNG file and extracts a chunk from it.
	#This function assumes that we are at the start of a chunk
	#This function will move the file handler forward
	
	#First, get the length bytes (4)
	var length_bytes = []
	for byte in range(4):
		length_bytes.append(png_file.get_8())
		
	#Now get the chunk type (4 bytes)
	var type_bytes = []
	for byte in range(4):
		type_bytes.append(png_file.get_8())
		
	#Using the length, get the data bytes
	var data_length = bytes_to_int(length_bytes)
	
	#Now grab that many bytes
	var data_bytes = []
	for byte in range(data_length):
		data_bytes.append(png_file.get_8())
		
	#Finally, grab the CRC (4 bytes)
	var crc_bytes = []
	for byte in range(4):
		crc_bytes.append(png_file.get_8())
		
	#We can return all this information
	return [length_bytes, type_bytes, data_bytes, crc_bytes]
	
	
static func bytes_to_int(bytes):
	#How many bytes are there?
	var total_bytes = len(bytes)
	
	#We want to calculate the integer value of all these bytes put together
	var value = 0
	for byte_index in range(total_bytes):
		#Get the byte
		var byte = bytes[byte_index]
		
		#How much to shift it over?
		var shift = (8 * ((total_bytes - byte_index) - 1))
		value += byte << shift
	
	#Return the final value
	return value
	
static func int_to_bytes(value, byte_count):
	#We need to convert the number to bytes with padding...
	var bytes = PoolByteArray()
	
	#Do we have enough bytes?
	while len(bytes) < byte_count:
		bytes.insert(0, value)
		value = value >> 8
		
	#Return these bytes
	return bytes
	
static func chunk_to_bytes(chunk_information):
	#Chunks are several pieces put together
	var bytes = []
	for byte_array in chunk_information:
		for byte in byte_array:
			bytes.append(byte)
	return bytes
	
static func build_crc_table():
	
	#Copied from: https://www.w3.org/TR/PNG/#D-CRCAppendix
	
	#Go over each byte value
	for n in range(256):
		#Go over each byte?
		var c = n
		for k in range(8):
			#Is N 1?
			if (c & 1):
				#Set it to some value
				c = 0xedb88320 ^ (c >> 1)
			else:
				#Just shift it
				c = c >> 1
		
		#Add it to the quick table
		crc_table.append(c)

static func update_crc(crc, buffer, size):
	#Do we have the quick table
	if len(crc_table) == 0:
		build_crc_table()
		
	#Go through each byte
	var c = crc
	for n in range(size):
		#Calculate the index
		var index = (c ^ buffer[n]) & 0xFF
		
		#Get the value from the table
		var value = crc_table[index]
		
		#Get the new C
		c = value ^ (c >> 8)
	
	#Return the new C
	return c
	
static func calculate_crc(buffer, size):
	#Simply get the next CRC?
	return update_crc(0xFFFFFFFF, buffer, size) ^ 0xFFFFFFFF
