Building on Linux
=================

This was tested using Windows XP SP2, with Microsoft Visual Studio 2005 Professional Edition


## Requirements:

Before building Jive you need to download and install the DirectX SDK from http://msdn2.microsoft.com/en-us/xna/aa937788.aspx.


## Instructions:

This process should be much simpler, please submit patches to improve this. Thanks :)

1. Open the Jive.sln file in Microsoft Visual Studio.

2. Press Ctrl-Shift-B to build the solution.

3. In the 'debug' or 'release' folder create a new folder named 'lua'.

4. Copy the following files and folders into this new directory:
	pkg\jive\share\applets
	pkg\jive\share\jive
	pkg\loop-2.2-alpha\loop
	pkg\luasocket-2.0.1\src\socket.lua
	pkg\luasocket-2.0.1\src\ltn12.lua
	pkg\luasocket-2.0.1\src\mime.lua
	pkg\lualogging-1.1.2\src\logging\logging.lua

5. In the 'lua' folder create a new folder named 'socket'.

6. Copy the following files and folders into this new directory:
	pkg\luasocket-2.0.1\src\ftp.lua
	pkg\luasocket-2.0.1\src\http.lua
	pkg\luasocket-2.0.1\src\smtp.lua
	pkg\luasocket-2.0.1\src\tp.lua
	pkg\luasocket-2.0.1\src\url.lua

7. In the 'debug' or 'release' output folder create a new folder named 'fonts'.

8. Copy the following files and folders into this new directory:
	pkg\freefont-debian\*.ttf

9. Copy from pkg\SDL_image-1.2.5\VisualC\graphics\lib\*.dll into the 'debug' or 'release' folder.


The jive.exe should now run.

Also TODO, creating a windows installer. I have had problems making the executable run on another PC. Again, patches please.


