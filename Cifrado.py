import sys
from cryptography.fernet import Fernet
#key = Fernet.generate_key() La idea es generar un string que sea: "usuario contraseña" con espacio, y el resultante de esa funcion colocarlo en la funci
#print(key)
f = Fernet(b"ggggggggggggggggggggggggggggggg=")
#token = f.encrypt(bytes(sys.argv[1],"ascii"))
#print(token)
DatoDes=f.decrypt(bytes(sys.argv[1],"ascii"))
print(DatoDes.decode("utf-8"))

