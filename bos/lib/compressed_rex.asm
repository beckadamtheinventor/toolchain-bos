
db $18, $04, "CRX", 0
dw filesize
virtual
	file DATA_FILE
	filesize := $-$$
end virtual
file COMPRESSED_FILE
