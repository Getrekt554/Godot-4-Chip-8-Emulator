extends Node2D

class Chip8:
	var modern = false
	var quit = false
	var audioplayer : AudioStreamPlayer2D
	var vx
	var vy
	var key_inputs = []
	var display_buffer = []
	var memory = []
	var gpio = []
	var sound_timer = 0
	var delay_timer = 0
	var index = 0
	var pc = 0x200
	var stack = []
	var opcode = 0
	var font = [0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
		   0x20, 0x60, 0x20, 0x20, 0x70, # 1
		   0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
		   0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
		   0x90, 0x90, 0xF0, 0x10, 0x10, # 4
		   0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
		   0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
		   0xF0, 0x10, 0x20, 0x40, 0x40, # 7
		   0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
		   0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
		   0xF0, 0x90, 0xF0, 0x90, 0x90, # A
		   0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
		   0xF0, 0x80, 0x80, 0x80, 0xF0, # C
		   0xE0, 0x90, 0x90, 0x90, 0xE0, # D
		   0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
		   0xF0, 0x80, 0xF0, 0x80, 0x80  # F
		   ]
	var funcmap = {
		0x0000: _0ZZZ,#honestly idek im tired 
		0x00e0: _0ZZ0,#CLS
		0x00ee: _0ZZE,#RET
		0x1000: _1ZZZ,#JP addr
		0x2000: _2ZZZ,#CALL addr
		0x3000: _3ZZZ,#SE vx, byte
		0x4000: _4ZZZ,#SNE vx, byte
		0x5000: _5ZZZ,#SE vx, vy
		0x6000: _6ZZZ,#LD vx, byte
		0x7000: _7ZZZ,#ADD vx, byte
		0x8000: _8ZZZ,#another one i cant quite explain because its late
		0x8ff0: _8ZZ0,#LD vx, vy
		0x8ff1: _8ZZ1,#OR vx, vy
		0x8ff2: _8ZZ2,#AND vx, vy
		0x8ff3: _8ZZ3,#XOR vx, vy
		0x8ff4: _8ZZ4,#ADD vx, vy
		0x8FF5: _8ZZ5,#SUB vx, vy
		0x8FF6: _8ZZ6,#SHR vx {,vy}
		0x8FF7: _8ZZ7,#SUBN vx, vy
		0x8FFE: _8ZZE,#SHL vx {, vy}
		0x9000: _9ZZZ,#SNE vx, vy
		0xA000: _AZZZ,#LD I, addr
		0xB000: _BZZZ,#JP v0, ADD
		0xC000: _CZZZ,#RND vx, vy, nibble
		0xD000: _DZZZ,#DRW vx, vy, nibble
		0xE000: _EZZZ,
		0xE00E: _EZZE,
		0xE001: _EZZ1,
		0xF000: _FZZZ,#im not gonna say it again
		0xF007: _FZ07, 
		0xF00A: _FZ0A,
		0xF015: _FZ15,
		0xF018: _FZ18,
		0xF01E: _FZ1E,
		0xF029: _FZ29,
		0xF033: _FZ33,
		0xF055: _FZ55,
		0xF065: _FZ65
	}

	func initialize() -> void:
		key_inputs.resize(16)
		key_inputs.fill(0)
		display_buffer.resize(64*32)
		display_buffer.fill(0)
		memory.resize(4096)
		memory.fill(0)
		gpio.resize(16)
		gpio.fill(0)
		
		for i in range(80):
			memory[i] = font[i]
	
	func load_rom(rom_path):
		print("Loading %s..." % rom_path)  # Log message
		var file = FileAccess.open(rom_path, FileAccess.READ)  # Create a new File object
		if file:  # Open the file in read mode
			var binary = file.get_buffer(file.get_length())  # Read the entire file into a buffer
			for i in range(binary.size()):
				memory[i + 0x200] = binary[i]  # Assign the byte to memory
			file.close()  # Always close the file after use
		else:
			print("Failed to load ROM: %s" % rom_path)  # Error message if the file can't be opened
			quit = true
			
	func get_key():
		for i in range(16):
			if key_inputs[i] == 1:
				last_key_pressed = i  # Store the last pressed key
				return i
		return -1
	
	#opcodes
	func _0ZZZ():
		#extract again to detect specific 0x0nnn opcode
		var extracted_op = opcode & 0xf0ff
		if funcmap.has(extracted_op):
			funcmap[extracted_op].call()
		else:
			print("unknown intructions:", opcode)
			quit = true
	func _0ZZ0():
		#clears the screen
		display_buffer.fill(0)
	func _0ZZE():
		#returns the sub routine
		pc = stack.pop_back()
	func _1ZZZ():
		#print("jumped to ", opcode & 0x0fff)
		#jumps to address nnn
		pc = opcode & 0x0fff
	func _2ZZZ():
		#Call subroutine at nnn.
		stack.append(pc)
		pc = opcode & 0x0fff
	func _3ZZZ():
		#Skip next instruction if Vx = kk.
		if gpio[vx] == (opcode & 0x0ff):
			pc += 2
	func _4ZZZ():
		#Skip next instruction if Vx != kk.
		if gpio[vx] != (opcode & 0x0ff):
			pc += 2
	func _5ZZZ():
		#skips next instruction if vx == vy
		if gpio[vx] == gpio[vy]:
			pc += 2
	func _6ZZZ():
		#Set Vx = kk.
		gpio[(opcode & 0x0f00) >> 8] = (opcode & 0x00ff)
	func _7ZZZ():
		# Extract the register index (vx) and the immediate value (kk)
		var kk = opcode & 0x00FF
		# Add kk to the register vx, wrapping around to 0-255
		gpio[(opcode & 0x0f00) >> 8] = (gpio[(opcode & 0x0f00) >> 8] + kk) % 256
	func _8ZZZ():
		#extract again to detect specific 0x8nnn opcode
		var extracted_op = opcode & 0xf00f
		extracted_op += 0xff0
		if funcmap.has(extracted_op):
			funcmap[extracted_op].call()
		else:
			print("unknown intruction:", opcode)
			quit = true
	func _8ZZ0():
		#Set Vx = Vy.
		gpio[vx] = gpio[vy]
		gpio[vx] &= 0xff
	func _8ZZ1():
		#set Vx = Vx OR Vy
		gpio[vx] = gpio[vx] | gpio[vy]
		gpio[vx] &= 0xff
		gpio[0xf] = 0
	func _8ZZ2():
		#set vx = vx AND vy
		gpio[vx] = gpio[vx] & gpio[vy]
		gpio[0xf] = 0
		gpio[vx] &= 0xff
	func _8ZZ3():
		#set vx = vx XOR vy
		gpio[vx] = gpio[vx] ^ gpio[vy]
		gpio[0xf] = 0
		gpio[vx] &= 0xff
	func _8ZZ4():
		var sum = gpio[vx] + gpio[vy]
		gpio[vx] = sum & 0xFF              # 8-bit wrap
		gpio[0xF] = 1 if sum > 255 else 0  # Carry flag
	func _8ZZ5():
		# Set Vx = Vx - Vy, set VF = NOT borrow
		var will_borrow = false
		if (gpio[vx] - gpio[vy]) < 0:
			will_borrow = true
		gpio[vx] = (gpio[vx] - gpio[vy]) & 0xff
		if will_borrow:
			gpio[0xf] = 0
		else:
			gpio[0xf] = 1
	func _8ZZ6():
		#Set Vx = Vx SHR 1.
		#some toggling for older vs modern versions of this opcode
		var rtbs = vx if modern else vy #rbts stands for "register to be shifted"
		var least_sig = gpio[rtbs] & 0x0001
		gpio[vx] = gpio[rtbs] >> 1
		gpio[0xf] = least_sig
	func _8ZZ7():
		#Set Vx = Vy - Vx, set VF = NOT borrow.
		gpio[vx] = gpio[vy] - gpio[vx]
		if gpio[vx] < 0: # i have no fucking clue why this works
			gpio[0xf] = 0
		else:
			gpio[0xf] = 1
		gpio[vx] &= 0xff
	func _8ZZE():
		#Set Vx = Vx SHL 1.
		#some toggling for older vs modern versions of this opcode
		var rtbs = vx if modern else vy #rbts stands for "register to be shifted"
		var most_sig = (gpio[rtbs] & 0x80) >> 7
		gpio[vx] = (gpio[rtbs] << 1) & 0xff
		gpio[0xf] = most_sig
	func _9ZZZ():
		#Skip next instruction if Vx != Vy.
		if gpio[(opcode & 0x0f00) >> 8] != gpio[(opcode & 0x00f0) >> 4]:
			pc += 2
	func _AZZZ():
		#set i = nnn
		index = opcode & 0xfff
	func _BZZZ():
		#jump to location nnn + v0
		pc = (opcode & 0x0fff) + gpio[0]
	func _CZZZ():
		#set vx to random byte AND kk
		gpio[vx] = randi_range(0, 255) & (opcode & 0x00ff)
		gpio[vx] &= 0xff
	func _DZZZ():
		# Extract X and Y from registers
		var x = gpio[vx] & 63  # X coordinate wrapped using modulo
		var y = gpio[vy] & 31  # Y coordinate wrapped using modulo
		gpio[0xF] = 0  # Reset VF flag (collision flag)
		var num_rows = opcode & 0x000F  # Height of the sprite
		for row in range(num_rows):
			var sprite_row = memory[index + row]  # Fetch sprite data
			for bit in range(8):
				if x + bit >= 64:  # Stop drawing if out of bounds (clipping)
					break
				var current_pixel = (sprite_row >> (7 - bit)) & 1  # Extract bit
				var screen_index = x + bit + (y * 64)  # Get screen buffer index
				if y >= 32:  # Stop drawing if out of bounds (clipping)
					break
				if screen_index < display_buffer.size():  # Prevent out-of-bounds
					var screen_pixel = display_buffer[screen_index]
					if current_pixel == 1:
						if screen_pixel == 1:
							gpio[0xF] = 1  # Collision detected
							display_buffer[screen_index] = 0  # Turn pixel off
						else:
							display_buffer[screen_index] = 1  # Turn pixel on
			y += 1  # Move to the next row
			if y >= 32:
				break  # Stop if out of bounds
	func _EZZZ():
		var extracted_opcode = opcode & 0xf00f
		if funcmap.has(extracted_opcode):
			funcmap[extracted_opcode].call()
		else:
			print("unknown instruction: %x" % opcode)
			quit = true
	func _EZZE():
		#Skip next instruction if key with the value of Vx is pressed.
		var key = gpio[vx] & 0xf
		if key_inputs[key] == 1:
			pc += 2
	func _EZZ1():
		#Skip next instruction if key with the value of Vx is not pressed.
		var key = gpio[vx] & 0xf
		if key_inputs[key] == 0:
			pc += 2
	func _FZZZ():
		var extracted_opcode = opcode & 0xf0ff
		if funcmap.has(extracted_opcode):
			funcmap[extracted_opcode].call()
		else:
			print("unkown instruction: %x" % opcode)
			quit = true
	func _FZ07():
		#set vx = delay timer value
		gpio[(opcode & 0x0f00) >> 8] = delay_timer
	var last_key_pressed = -1
	func _FZ0A():
		if last_key_pressed >= 0:
			gpio[(opcode & 0x0f00) >> 8] = last_key_pressed
			last_key_pressed = -1  # Reset after storing
		else:
			pc -= 2  # Stall until a key is pressed
	func _FZ15():
		#set delay timer = vx
		delay_timer = gpio[(opcode & 0x0f00) >> 8]
	func _FZ18():
		#set sound timer to vx
		sound_timer = gpio[vx]
	func _FZ1E():
		#set i = i + vx
		index += gpio[vx]
		if index > 0xfff:
			gpio[0xf] = 1
			index &= 0xfff
		else:
			gpio[0xf] = 1
	func _FZ29():
		#set index to point to a character
		index = (5*(gpio[vx])) & 0xfff
	func _FZ33():
		#Store BCD representation of Vx in memory locations I, I+1, and I+2.
		memory[index] = gpio[vx] / 100
		memory[index + 1] = (gpio[vx] % 100) / 10
		memory[index + 2] = gpio[vx] % 10
	func _FZ55():
		#Store registers V0 through Vx in memory starting at location I.
		var i = 0
		while i <= vx:
			memory[index + i] = gpio[i]
			i += 1
		index += vx + 1
	func _FZ65():
		#Read registers V0 through Vx from memory starting at location I.
		var i = 0
		while i <= vx:
			gpio[i] = memory[index+i]
			i += 1
		index += vx + 1
	#end instructions
	
	func cycle():
		opcode = (memory[pc] << 8) | memory[pc + 1]
		pc += 2
		
		vx = (opcode & 0x0f00) >> 8
		vy = (opcode & 0x00f0) >> 4
		if not quit:
			#check opcode lookup and execute
			var extracted_op = opcode & 0xf000
			if funcmap.has(extracted_op):
				funcmap[extracted_op].call()
			else:
				print("unknown intruction:%x" % opcode)
				quit = true
		
		
		
	func main(program):
		initialize()
		load_rom(program)

@onready var comp = Chip8.new()
@onready var file_dialog = FileDialog.new()
var selected_rom_path: String = ""

func _select_rom():
	file_dialog.popup_centered_ratio(0.5)
	selected_rom_path = await file_dialog.file_selected

func _ready() -> void:
	# Configure the file dialog
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.ch8 ; ROMS"] # Adjust as needed
	file_dialog.title = "Select a ROM File"
	
	# Add the dialog to the scene and show it
	add_child(file_dialog)
	# Show dialog and wait for the user's selection
	await _select_rom()

	comp.audioplayer = $AudioStreamPlayer2D
	comp.main(selected_rom_path)
	if comp.quit:
		get_tree().quit(1)

var timer_accumulator = 0.0
var cycle_accumulator = 0.0  # Accumulates time for cycle execution
var cycles_per_second = 700   # Adjust based on performance

func _process(delta: float) -> void:
	if selected_rom_path != "":
		if comp.quit:
			get_tree().quit(1)
		
		var prev_inputs = comp.key_inputs.duplicate()  # Save previous key states
		comp.key_inputs[0] = 1 if Input.is_action_pressed("0") else 0
		comp.key_inputs[1] = 1 if Input.is_action_pressed("1") else 0
		comp.key_inputs[2] = 1 if Input.is_action_pressed("2") else 0
		comp.key_inputs[3] = 1 if Input.is_action_pressed("3") else 0
		comp.key_inputs[4] = 1 if Input.is_action_pressed("4") else 0
		comp.key_inputs[5] = 1 if Input.is_action_pressed("5") else 0
		comp.key_inputs[6] = 1 if Input.is_action_pressed("6") else 0
		comp.key_inputs[7] = 1 if Input.is_action_pressed("7") else 0
		comp.key_inputs[8] = 1 if Input.is_action_pressed("8") else 0
		comp.key_inputs[9] = 1 if Input.is_action_pressed("9") else 0
		comp.key_inputs[10] = 1 if Input.is_action_pressed("10") else 0
		comp.key_inputs[11] = 1 if Input.is_action_pressed("11") else 0
		comp.key_inputs[12] = 1 if Input.is_action_pressed("12") else 0
		comp.key_inputs[13] = 1 if Input.is_action_pressed("13") else 0
		comp.key_inputs[14] = 1 if Input.is_action_pressed("14") else 0
		comp.key_inputs[15] = 1 if Input.is_action_pressed("15") else 0

		
		# Ensure keys persist between frames
		if prev_inputs != comp.key_inputs:
			comp.cycle()  # Process an extra cycle when keys change

		# Timer update (60Hz)
		timer_accumulator += delta
		while timer_accumulator >= (1.0 / 60.0):
			timer_accumulator -= (1.0 / 60.0)
			if comp.delay_timer > 0:
				comp.delay_timer -= 1
			if comp.sound_timer > 0:
				comp.sound_timer -= 1
				if comp.sound_timer == 0:
					comp.audioplayer.play()

		# Emulator cycles update (~700Hz)
		cycle_accumulator += delta
		while cycle_accumulator >= (1.0 / cycles_per_second):
			cycle_accumulator -= (1.0 / cycles_per_second)
			comp.cycle()  # Call the cycle function to execute instructions

		queue_redraw()  # Request a screen redraw


func _draw() -> void:
	if selected_rom_path != "":
		for x in range(64):
			for y in range(32):
				draw_rect(Rect2(Vector2(x,y), Vector2(1,1)), Color8(255,255,255) if comp.display_buffer[x+(y*64)] == 1 else Color8(0,0,0))
