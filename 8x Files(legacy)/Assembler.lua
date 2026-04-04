local OPCODES = { --two bits are put in front of OPCODES as the immediates
    ADD = "000000",
    MOV = "000000", --MOV is just add, but add to 0. I added it for readability
    SUB = "000001",
    AND = "000010",
    NAND = "000011",
    OR = "000100",
    NOR = "000101",
    XOR = "000110",
    EQUAL = "100000", --compare operand 1 and 2, jump if equal
    NEQ = "100001", --compare operand 1 and 2, jump if
    GREATER = "100010", --compare operand 1 and 2, jump if operand 1 > operand 2
    LESS = "100011", --compare operand 1 and 2, jump if operand 1 < operand 2
    GRorEQ = "100100", --compare operand 1 and 2, jump if operand 1 >= operand 2
    LessorEQ = "100101", --compare operand 1 and 2, jump if operand 1 <= operand 2
    JUMP = "100110" --compare with ALWAYS argument, ignores operand 1 and 2 and jumps
}

local Operands = {
    R0 = "00000000",
    R1 = "00000001",
    R2 = "00000010",
    R3 = "00000011",
    R4 = "00000100",
    R5 = "00000101",
}

--IMM's (immediates) tell you to take the specified operand (1 or 2) as a number or a source
local code = {
    -- 1. Setup: R0 = 3 (The counter), R1 = 0 (The accumulator)
    {"IMM1", "IMM2", "MOV", "3", "0", "R0"},
    {"IMM1", "IMM2", "MOV", "0", "0", "R1"},

    -- 2. Add R0 to R1 (Accumulating)
    {"ADD", "R1", "R0", "R1"}, -- Result: 3, then 5, then 6...

    -- 3. Decrement R0 (The counter)
    {"IMM2", "SUB", "R0", "1", "R0"}, -- Result: 2, then 1, then 0...

    -- 4. Check if R0 > 0. If so, jump back to Line 2.
    -- Assuming Line 2 is Address "2".
    {"IMM2", "GREATER", "R0", "0", "2"}, 

    -- 5. Final result is in R1. Move it to R5 for the final answer.
    {"MOV", "R1", "0", "R5"}
}


local Flags = { --Programming Structure
    IMM1 = false, 
    IMM2 = false, 
    OPCODE = false, 
    OPERAND1 = false, 
    OPERAND2 = false, 
    DESTINATION = false
}

local function SetUpFile()
    local HexFile = io.open("BinProgramInstructions.hex", "wb") 
    if not HexFile then
        print("Error opening file for writing.")
        os.exit()
    end
    HexFile:write("v2.0 raw\n") --header

    return HexFile
end

------Utility Functions------
local function TableHas(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end
local function ResetFlags()
    for key in pairs(Flags) do
        Flags[key] = false
    end
end
local function FourByteVerifier(byte)
    if #byte ~= 32 then
        print("Error: Byte must be 32 bits long.")
        return false
    end
    if not byte:match("^[01]+$") then
        print("Error: Byte must contain only 0s and 1s.")
        return false
    end
    return true
end
local function toBinary(n)
    if n==0 then return "00000000" end

    local bits = {}
    while n> 0 do
        table.insert(bits, 1, (n&1))
        n = n>>1
    end
    local string = table.concat(bits)
    local EightBit = string.sub("00000000"..string, -8)
    return EightBit
end
local function DecimalToHexAndWrite(HexFile, binaryString)
    print("Binary String: "..binaryString)
    FourByteVerifier(binaryString) --verify the binary string is 32 bits and only contains 0s and 1s

    local hexString = ""
    for i = 1, #binaryString, 4 do
        local nibble = binaryString:sub(i, i + 3)
        local decimal = tonumber(nibble, 2)
        hexString = hexString .. string.format("%X", decimal)
    end
    HexFile:write(hexString .. "\n")
    print("Hex String: "..hexString)
end

------OPCODE------
local function AssembleOPCODE(line, TableIndex, bits)
    for i=1, 2 do --both immediates
        if TableHas(line, "IMM"..i) then
                table.insert(bits, 1)
            Flags["IMM"..i] = true
            TableIndex = (TableIndex or 0) + 1 --proceed i because the immediate takes up that slot in the line
        else
            table.insert(bits, 0)
        end
    end

    local OpBin = OPCODES[line[TableIndex]]
    if OpBin then --By now, tableindex should have progressed past the IMM's and land on the OPCODES
        table.insert(bits, OpBin)
    else
        print(line[TableIndex].." is not valid.")
    end
    TableIndex = (TableIndex or 0) + 1

    return TableIndex, bits
end

------Operands------
local function BuildOperand(i, line, bits, TableIndex)
    local term = Operands[line[TableIndex]]

    if Flags["IMM"..i] then
        local Imm = tonumber(line[TableIndex])
        if Imm then
            local bin = toBinary(Imm)
            table.insert(bits, bin) --convert to 8 bit binary
        else
            print(line[TableIndex].." is not a valid immediate value.")
        end
        TableIndex = (TableIndex or 0) + 1
    elseif term then
        table.insert(bits, term)
        TableIndex = (TableIndex or 0) + 1
    elseif tonumber(line[TableIndex]) then
        table.insert(bits, toBinary(tonumber(line[TableIndex])))
        TableIndex = (TableIndex or 0) + 1
    else
        print(line[TableIndex].." is not a valid operand.")
    end

    return bits, TableIndex
end
local function AssembleOPERANDS(line, TableIndex, bits)
    for i = 1, 2 do
        bits, TableIndex = BuildOperand(i, line, bits, TableIndex)
    end

    return TableIndex, bits
end

------Destination------
local function AssembleDESTINATION(line, TableIndex, bits)
    local term = Operands[line[TableIndex]]
    if term then
        table.insert(bits, term)
    elseif tonumber(line[TableIndex]) then
        table.insert(bits, toBinary(tonumber(line[TableIndex])))
    else
        print(TableIndex)
        print(line[TableIndex].." is not a valid destination operand.")
    end
    TableIndex = (TableIndex or 0) + 1

    return TableIndex, bits
end

 --Main Stack
local function Main(HexFile)
    for _, line in ipairs(code) do
        local TableIndex = 1
        local bits = {}
        ResetFlags() --reset all flags for each instruction

        TableIndex, bits = AssembleOPCODE(line, TableIndex, bits)
        TableIndex, bits = AssembleOPERANDS(line, TableIndex, bits)
        TableIndex, bits = AssembleDESTINATION(line, TableIndex, bits)

        local bin = table.concat(bits)

        DecimalToHexAndWrite(HexFile, bin) --convert the binary string to hex and write to file
    end
end

local HexFile = SetUpFile()
Main(HexFile)
HexFile:close()