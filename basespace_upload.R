### basespace_upload.r
###


require(BaseSpaceR)
data(aAuth)
aAuth

u <- Users(aAuth)
u
Id(u)
Name(u)
Users(aAuth, id = 1463464)
Users(aAuth, id = "1463464")
