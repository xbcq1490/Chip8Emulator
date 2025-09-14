<img src="./docs/logo.png" style="height:64px;margin-right:32px"/>

***

A simple CHIP8 emulator written in Lua using the LOVE2D library
This is my **first project** using love2d, so the code might be bad. **BUT** its still usable.

## ✨ Features

- **Full instruction set** - All opcodes implemented, including display drawing and timers
- **Graphics** - 64×32 black and white display built with love2d
- **Sound** - Simple beep sound when ST (sound timer) is active
- **Input** - Hex keypad thats mapped to a keyboard
- **Rom loading** - Drag and drop a `.ch8` rom binary
- **Debbuging** - Window title shows the pc

## 🎮 Controls

- **Key correspondings** 
```
1 2 3 4 > 1 2 3 C
Q W E R > 4 5 6 D
A S D F > 7 8 9 E
Z X C V > A 0 B F
```
- **Space** Toggle execution
- **Drag and Drop** → Load a `.ch8` binary into the emulator


## 🚀 Getting Started

### Requirements
- [LOVE](https://love2d.org/) installed on your system

### Run the Emulator
Run the emulator from your project directory using `love .`

### Load a ROM
- Drag and drop a `.ch8` binary into the window
- The program counter starts at 0x200 (normal chip8 starting point)

### Where can i find roms?
- https://github.com/kripod/chip8-roms, alternatively you can use the roms in the "examples" folder.

## 📖 How It Works

- **CPU Cycle** - Fetch > Decode > Execute with customizable cycle per frame
- **Memory** - 4k ram (`0x000`-`0xFFF`), fontset loaded at 0x50, roms at 0x200 
- **Timers** - Delay and sound timers clock down at approx 60hz 
- **Display** - Pixels drawn using `love.graphics.rectangle()`  
- **Sound** - Beeps generated using `love.audio.newSource()`  

## ⚠️ Limitations

- Code is experimental and garbage (**my first love project**)
- No built in debugger or disassembler
- Only supports normal chip8 programs

---

## 📝 License

This project is open-source under the MIT License.  
Feel free to fork, improve, or even roast the code i made.

---

Made with "*love*" ❤️ for the emulation community

Thanks to the creator of this site btw!! http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#3xkk