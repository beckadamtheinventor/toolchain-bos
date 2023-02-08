
;-------------------------------------------------------------------------------
; Executable formats
;-------------------------------------------------------------------------------
macro ram_executable?
	ram_executable_at ti.userMem
end macro

macro ram_executable_at? addr
	org addr
	db $18,$04,"REX",$00
end macro

macro flash_executable?
	local relocations_enabled
	db $18,$04,"FEX",$00
	macro end?.flash_executable?
		iterate opcode,  call, jp, jq, ld
			restore opcode
		end iterate
		purge end?.flash_executable?
	end macro
	macro flash_executable_enable_relocations
		relocations_enabled = 1
	end macro
	macro flash_executable_disable_relocations
		relocations_enabled = 0
	end macro
	relocations_enabled = 1
	iterate opcode,  call, jp, jq, ld
		macro opcode? args&
			if relocations_enabled = 1
				match lhs=,rhs, args
					match (val), lhs
						if val relativeto 0 & val >= $01000000
							if val >= ___data & val < ___data + ___data_length
								opcode (0), rhs
								store (val + $D1A881 + 5 + ___libs_length - ___data) : 3 at $ - 3
							else if val >= ___libs & val < ___libs + ___libs_length
								opcode (0), rhs
								store (val + $D1A881 - ___libs) : 3 at $ - 3
							else
								rst $28
								opcode (0), rhs
								store (val - $) : 3 at $ - 3
							end if
						else
							opcode (val), rhs
						end if
					else match (val), rhs
						if val relativeto 0 & val >= $01000000
							if val >= ___data & val < ___data + ___data_length
								opcode lhs, (0)
								store (val + $D1A881 + 5 + ___libs_length - ___data) : 3 at $ - 3
							else if val >= ___libs & val < ___libs + ___libs_length
								opcode lhs, (0)
								store (val + $D1A881 - ___libs) : 3 at $ - 3
							else
								rst $28
								opcode lhs, (0)
								store (val - $) : 3 at $ - 3
							end if
						else
							opcode lhs, (val)
						end if
					else if rhs relativeto 0 & rhs >= $01000000
						if rhs >= ___data & rhs < ___data + ___data_length
							opcode lhs, 0
							store (rhs + $D1A881 + 5 + ___libs_length - ___data) : 3 at $ - 3
						else if rhs >= ___libs & rhs < ___libs + ___libs_length
							opcode lhs, 0
							store (rhs + $D1A881 - ___libs) : 3 at $ - 3
						else
							rst $28
							opcode lhs, 0
							store (rhs - $) : 3 at $ - 3
						end if
					else
						opcode lhs, rhs
					end if
				else match opcode= lhs, args
					match (val), lhs
						opcode lhs
					else if lhs relativeto 0 & lhs >= $01000000
						if lhs >= ___data & lhs < ___data + ___data_length
							opcode 0
							store (lhs + $D1A881 + 5 + ___libs_length - ___data) : 3 at $ - 3
						else if lhs >= ___libs & lhs < ___libs + ___libs_length
							opcode 0
							store (lhs + $D1A881 - ___libs) : 3 at $ - 3
						else
							rst $28
							opcode 0
							store (lhs - $) : 3 at $ - 3
						end if
					else
						opcode lhs
					end if
				else
					opcode args
				end match
			else
				opcode args
			end if
		end macro
	end iterate
end macro

;-------------------------------------------------------------------------------
; Software threading instructions
;-------------------------------------------------------------------------------
macro EnableThreading?
	rst $10
	nop
end macro

macro EnableOSThreading?
	rst $10
	rst $28
end macro

macro DisableThreading?
	rst $10
	rst $38
end macro

macro SleepThread?
	rst $10
	halt
end macro

macro WakeThread?
	rst $10
	rst $20
end macro

macro EndThread?
	rst $10
	ret
end macro

macro SpawnThread? start_pc, start_sp
	rst $10
	push bc
	dl start_sp
	dl start_pc
end macro

macro HandleNextThread?
	rst $10
	pop bc
end macro

macro HandleNextThread_IfOSThreading?
	rst $10
	rst $30
end macro

;-------------------------------------------------------------------------------
; Device macros
;-------------------------------------------------------------------------------

macro device_file? flags, type, version, intsource
	virtual
	db $C9, flags, type, version, intsource, 0, 0, 0
	repeat device_NumJumps
		or a,a
		sbc hl,hl
		ret
	end repeat
	macro export? jumpno, function
		if function > 0
			store $C9: byte at $$+jumpno
			store function: 3 at $$+jumpno+1
		end if
	end macro
	macro end?.device_file?
		local data
		load data: $-$$ from $$
		end virtual
		db data
		purge export?
	end macro
end macro
