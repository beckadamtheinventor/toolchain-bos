
db $18, $04, "CRX", 0
dw filesize
filedata:
file DATA_FILE
filesize := $ - filedata