import sys
from cryptography.fernet import Fernet
#key = Fernet.generate_key()
#print(key)
f = Fernet(b"t26WaPWVK9z0zndajIw9MJTCZBuCfACVVEkZhtbh_tg=")
#token = f.encrypt(bytes(sys.argv[1],"ascii"))
#print(token)
DatoDes=f.decrypt(bytes(sys.argv[1],"ascii"))
print(DatoDes.decode("utf-8"))

