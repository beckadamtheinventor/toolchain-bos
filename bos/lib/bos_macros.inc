
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
		db $18,$04,"FEX",$00
	macro end?.flash_executable?
		iterate opcode,  call, jp, jq, ld
			restore opcode
		end iterate
		purge end?.flash_executable?
	end macro
	iterate opcode,  call, jp, jq, ld
		macro opcode? args&
			match lhs=,rhs, args
				match (val), lhs
					if val relativeto 0 & val >= $01000000
						rst $28
						opcode (0), rhs
						store (val and $FFFFFF) - $ : 3 at $ - 3
					else
						opcode (val), rhs
					end if
				else match (val), rhs
					if val relativeto 0 & val >= $01000000
						rst $28
						opcode lhs, (0)
						store (val and $FFFFFF) - $ : 3 at $ - 3
					else
						opcode lhs, (val)
					end if
				else if rhs relativeto 0 & rhs >= $01000000
					rst $28
					opcode lhs, 0
					store (rhs and $FFFFFF) - $ : 3 at $ - 3
				else
					opcode lhs, rhs
				end if
			else match opcode= lhs, args
				match (val), lhs
					opcode lhs
				else if lhs relativeto 0 & lhs >= $01000000
					rst $28
					opcode 0
					store (lhs and $FFFFFF) - $ : 3 at $ - 3
				else
					opcode lhs
				end if
			else
				opcode args
			end match
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
