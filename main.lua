--my first love2d project, bad code ik.
--hex keypad (i )
--1 2 3 C
--4 5 6 D
--7 8 9 E
--A 0 B F

local bit32 = require("bit")

local chip8 = {
    pc = 0x200, --program counter
    opcode = 0, --current opcode
    I = 0, --index register
    sp = 0, --stack poniter
    V = {}, --16 registers for everything
    memory = {}, --memory address range (max is 0xffff, which is 65535)
    stack = {}, --call stack
    display = {}, --64x32 display (2:1)
    delay_timer = 0,
    sound_timer = 0,
    keys = {}, --16 keys as in the hex keypad above this
    waiting_for_key = false,
    waiting_reg = 0,
    running = false --either HALT or RUN
}

--cpu
local cycles_per_frame = 10
local timer_accum = 0
local timer_hz = 60 --tried to experiment with 120, literally works the same

--thanks chatgpt for this "awesome" font set!1!
local fontset = {0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70, 0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10,
                 0xF0, 0x10, 0xF0, 0x90, 0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0, 0xF0, 0x80, 0xF0, 0x90,
                 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40, 0xF0, 0x90, 0xF0, 0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0, 0xF0,
                 0x90, 0xF0, 0x90, 0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0xE0, 0x90, 0x90,
                 0x90, 0xE0, 0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0, 0x80, 0xF0, 0x80, 0x80}

--key map, idk if this is even correct but it works
local keymap = {
    ["x"] = 0x0,
    ["1"] = 0x1,
    ["2"] = 0x2,
    ["3"] = 0x3,
    ["4"] = 0xC,
    ["q"] = 0x4,
    ["w"] = 0x5,
    ["e"] = 0x6,
    ["r"] = 0xD,
    ["a"] = 0x7,
    ["s"] = 0x8,
    ["d"] = 0x9,
    ["f"] = 0xE,
    ["z"] = 0xA,
    ["c"] = 0xB,
    ["v"] = 0xF
}

--beep
local beepSource = nil

local function reset()
    chip8.pc = 0x200 --start again from 0x200
    chip8.opcode = 0
    chip8.I = 0
    chip8.sp = 0
    chip8.delay_timer = 0
    chip8.sound_timer = 0
    chip8.waiting_for_key = false
    chip8.waiting_reg = 0
    chip8.running = false

    for i = 0, 15 do
        chip8.V[i] = 0
    end
    for i = 0, 4095 do
        chip8.memory[i] = 0
    end
    for i = 0, 15 do
        chip8.stack[i] = 0
    end
    --clear display
    for y = 0, 31 do
        chip8.display[y] = {}
        for x = 0, 63 do
            chip8.display[y][x] = 0
        end
    end

    --load fontset into memory
    for i = 1, #fontset do
        chip8.memory[0x50 + (i - 1)] = fontset[i]
    end
end

local function makeBeep()
    local rate = 44100
    local duration = 0.1
    local frames = math.floor(rate * duration)
    local sd = love.sound.newSoundData(frames, rate, 16, 1)
    local freq = 440
    for i = 0, frames - 1 do
        local t = i / rate
        local s = math.sin(2 * math.pi * freq * t) * 0.3
        sd:setSample(i, s)
    end
    local src = love.audio.newSource(sd, "static")
    src:setLooping(true)
    return src
end

local function fetch()
    --halt if the memory is under or above 65535
    if chip8.pc < 0 or chip8.pc > 0xFFF or (chip8.pc + 1) > 0xFFF then
        chip8.running = false
        return
    end
    local hi = chip8.memory[chip8.pc] or 0
    local lo = chip8.memory[chip8.pc + 1] or 0
    chip8.opcode = bit32.lshift(hi, 8) + lo
    chip8.pc = chip8.pc + 2
end

local function drawSprite(x0, y0, n)
    chip8.V[0xF] = 0
    for row = 0, n - 1 do
        local spriteByte = chip8.memory[chip8.I + row] or 0
        for col = 0, 7 do
            local mask = bit32.rshift(0x80, col)
            local pixelOn = bit32.band(spriteByte, mask) ~= 0
            if pixelOn then
                local x = (x0 + col) % 64
                local y = (y0 + row) % 32
                if chip8.display[y][x] == 1 then
                    chip8.V[0xF] = 1
                end
                chip8.display[y][x] = bit32.bxor(chip8.display[y][x], 1)
            end
        end
    end
end

local function execute()
    if not chip8.running then
        return
    end
    local op = chip8.opcode
    local nnn = bit32.band(op, 0x0FFF)
    local n = bit32.band(op, 0x000F)
    local x = bit32.band(bit32.rshift(op, 8), 0x000F)
    local y = bit32.band(bit32.rshift(op, 4), 0x000F)
    local kk = bit32.band(op, 0x00FF)
    local top = bit32.band(op, 0xF000)

    if top == 0x0000 then
        if op == 0x00E0 then
            --clear screen
            for y = 0, 31 do
                for x = 0, 63 do
                    chip8.display[y][x] = 0
                end
            end
        elseif op == 0x00EE then
            --ret
            if chip8.sp <= 0 then
                chip8.running = false;
                return
            end
            chip8.sp = chip8.sp - 1
            chip8.pc = chip8.stack[chip8.sp]
        elseif op == 0x0000 then
            --treat it as halt to avoid running into garbage memory
            chip8.running = false
        end

    elseif top == 0x1000 then
        --JMP addres
        --print("Jumping to:", nnn, "From:", chip8.pc)
        chip8.pc = nnn

    elseif top == 0x2000 then
        --CALL addr
        if chip8.sp >= 16 then
            chip8.running = false;
            return
        end
        chip8.stack[chip8.sp] = chip8.pc
        chip8.sp = chip8.sp + 1
        chip8.pc = nnn

    elseif top == 0x3000 then
        --SE Vx, byte
        if chip8.V[x] == kk then
            chip8.pc = chip8.pc + 2
        end

    elseif top == 0x4000 then
        --SNE Vx, byte
        if chip8.V[x] ~= kk then
            chip8.pc = chip8.pc + 2
        end

    elseif top == 0x5000 then
        --SE Vx, Vy
        if bit32.band(op, 0x000F) == 0x0 then
            if chip8.V[x] == chip8.V[y] then
                chip8.pc = chip8.pc + 2
            end
        end

    elseif top == 0x6000 then
        --LD Vx, byte
        chip8.V[x] = kk

    elseif top == 0x7000 then
        --ADD Vx, byte
        chip8.V[x] = (chip8.V[x] + kk) % 256

    elseif top == 0x8000 then
        local sub = bit32.band(op, 0x000F)
        if sub == 0x0 then
            --LD Vx, Vy
            chip8.V[x] = chip8.V[y]
        elseif sub == 0x1 then
            --OR Vx, Vy
            chip8.V[x] = bit32.bor(chip8.V[x], chip8.V[y])
        elseif sub == 0x2 then
            --AND Vx, Vy
            --wtf?
            --print(bit32.band(chip8.V[x], chip8.V[y]))
            chip8.V[x] = bit32.band(chip8.V[x], chip8.V[y])
        elseif sub == 0x3 then
            --XOR Vx, Vy
            --this too?
            --print(bit32.bxor(chip8.V[x], chip8.V[y]))
            chip8.V[x] = bit32.bxor(chip8.V[x], chip8.V[y])
        elseif sub == 0x4 then
            --ADD Vx, Vy
            local sum = chip8.V[x] + chip8.V[y]
            chip8.V[0xF] = (sum > 255) and 1 or 0
            chip8.V[x] = bit32.band(sum, 0xFF)
        elseif sub == 0x5 then
            --SUB Vx, Vy
            chip8.V[0xF] = (chip8.V[x] > chip8.V[y]) and 1 or 0
            chip8.V[x] = bit32.band(chip8.V[x] - chip8.V[y], 0xFF)
        elseif sub == 0x6 then
            --SHR Vx
            chip8.V[0xF] = bit32.band(chip8.V[x], 0x1)
            local res = bit32.rshift(chip8.V[x], 1)
            chip8.V[x] = res
        elseif sub == 0x7 then
            --SUBN Vx, Vy
            chip8.V[0xF] = (chip8.V[y] > chip8.V[x]) and 1 or 0
            chip8.V[x] = bit32.band(chip8.V[y] - chip8.V[x], 0xFF)
        elseif sub == 0xE then
            --SHL Vx
            chip8.V[0xF] = bit32.band(bit32.rshift(chip8.V[x], 7), 0x1)
            local res = bit32.lshift(chip8.V[x], 1) % 256
            chip8.V[x] = res
        end

    elseif top == 0x9000 then
        --SNE Vx, Vy
        if bit32.band(op, 0x000F) == 0x0 then
            if chip8.V[x] ~= chip8.V[y] then
                chip8.pc = chip8.pc + 2
            end
        end

    elseif top == 0xA000 then
        --LD I, addr
        chip8.I = nnn

    elseif top == 0xB000 then
        --JP V0, addr
        chip8.pc = (nnn + chip8.V[0]) % 0x1000

    elseif top == 0xC000 then
        --RND Vx, byte
        local rnd = love.math.random(0, 255)
        chip8.V[x] = bit32.band(rnd, kk)

    elseif top == 0xD000 then
        --DRW Vx, Vy
        local x0 = chip8.V[x] % 64
        local y0 = chip8.V[y] % 32
        drawSprite(x0, y0, n)

    elseif top == 0xE000 then
        local key = bit.band(chip8.V[x], 0xF)
        if kk == 0x9E then
            --SKP Vx
            if chip8.keys[key] then
                chip8.pc = chip8.pc + 2
            end
        elseif kk == 0xA1 then
            --SKNP Vx
            if not chip8.keys[key] then
                chip8.pc = chip8.pc + 2
            end
        end

    elseif top == 0xF000 then
        if kk == 0x07 then
            --LD Vx, DT
            chip8.V[x] = chip8.delay_timer
        elseif kk == 0x0A then
            --LD Vx, K
            chip8.waiting_for_key = true
            chip8.waiting_reg = x
        elseif kk == 0x15 then
            --LD DT, Vx
            chip8.delay_timer = chip8.V[x]
        elseif kk == 0x18 then
            --LD ST, Vx
            chip8.sound_timer = chip8.V[x]
        elseif kk == 0x1E then
            --ADD I, Vx
            chip8.I = (chip8.I + chip8.V[x]) % 0x1000
        elseif kk == 0x29 then
            --LD F, Vx
            chip8.I = 0x50 + (chip8.V[x] % 16) * 5
        elseif kk == 0x33 then
            --LD B, Vx
            local v = chip8.V[x]
            chip8.memory[chip8.I] = math.floor(v / 100)
            chip8.memory[chip8.I + 1] = math.floor((v % 100) / 10)
            chip8.memory[chip8.I + 2] = v % 10
        elseif kk == 0x55 then
            --LD I, V0 Vx
            for i = 0, x do
                chip8.memory[chip8.I + i] = chip8.V[i]
            end
            chip8.I = chip8.I + x + 1 --memory increments remove if needed
        elseif kk == 0x65 then
            --LD V0 Vx
            for i = 0, x do
                chip8.V[i] = chip8.memory[chip8.I + i] or 0
            end
            chip8.I = chip8.I + x + 1 --memory increments remove if needed
        end
    else
        --unknown opcode!?!
        chip8.running = false
    end
end

local function cycle()
    if not chip8.running then
        return
    end
    if chip8.waiting_for_key then
        return
    end
    fetch()
    if not chip8.running then
        return
    end
    execute()
end

--love
function love.load()
    love.window.setMode(768, 384)
    love.window.setTitle("chip 8 emu (put .ch8 file)")
    love.graphics.setBackgroundColor(0, 0, 0)
    love.math.setRandomSeed(os.time())
    reset()
    beepSource = makeBeep()
end

function love.update(dt)
    --run cpu cycles unless waiting for key or halted
    if not chip8.waiting_for_key and chip8.running then
        for i = 1, cycles_per_frame do
            cycle()
            if not chip8.running or chip8.waiting_for_key then
                break
            end
        end
    end

    --timers at 60hz
    timer_accum = timer_accum + dt
    local step = 1 / timer_hz
    while timer_accum >= step do
        if chip8.delay_timer > 0 then
            chip8.delay_timer = chip8.delay_timer - 1
        end
        if chip8.sound_timer > 0 then
            chip8.sound_timer = chip8.sound_timer - 1
        end
        timer_accum = timer_accum - step
    end

    --beep control
    if chip8.sound_timer > 0 then
        if not beepSource:isPlaying() then
            beepSource:play()
        end
    else
        if beepSource:isPlaying() then
            beepSource:stop()
        end
    end
end

function love.draw()
    --very simple graphics since its only black and white
    for y = 0, 31 do
        for x = 0, 63 do
            local px = chip8.display[y][x]
            if px == 1 then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0, 0, 0)
            end
            love.graphics.rectangle("fill", x * 12, y * 12, 12, 12) -- 12 since 768 / 64 = 12
        end
    end

    --debug 
    love.graphics.setColor(1,1,1)
    love.window.setTitle("chip 8 emu pc: "..("%04X"):format(chip8.pc), 0,0)
end

function love.keypressed(key)
    if keymap[key] ~= nil then
        local code = keymap[key]
        chip8.keys[code] = true
        if chip8.waiting_for_key then
            chip8.V[chip8.waiting_reg] = code
            chip8.waiting_for_key = false
        end
    end
    if key == "space" then
        chip8.running = not chip8.running
    end
end

function love.keyreleased(key)
    if keymap[key] ~= nil then
        chip8.keys[keymap[key]] = false
    end
end

function love.filedropped(file)
    file:open("r")
    local bytes = file:read()
    file:close()
    reset()
    --load bytes at 0x200
    for i = 0, #bytes - 1 do
        chip8.memory[0x200 + i] = bytes:byte(i + 1)
    end
    chip8.running = true
end
