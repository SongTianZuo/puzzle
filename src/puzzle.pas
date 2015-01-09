{$APPTYPE GUI}
{$mode delphi}
uses
	Frame,windows;

const
	bmpfile='puzzle.bmp';
	bgSound:String='sound/bg.mid';
	wavWin:String='sound/win.wav';
	wavMove:String='sound/move.wav';

	{窗体宽度，高度}
	WINDOW_WIDTH=610;
	WINDOW_HEIGHT=320;

	{菜单常量}
	IDM_GAME_NEW=1;
	IDM_GAME_L1=2;
	IDM_GAME_L2=3;
	IDM_GAME_L3=4;
	IDM_GAME_L4=5;
	IDM_GAME_MUSIC=6;
	IDM_HELP_ABOUT=7;

	{MM_MCINOTIFY}
	MM_MCINOTIFY=$3B9; 

var
hFormMenu: hMenu; {窗口菜单}
hWindow: hwnd;{窗口句柄}
level : integer=1; {难度}
isPlaying : boolean=false;
isWinned : boolean= false;
bPlayBgMusic: boolean=true;
isMoveOneLeft:boolean=false;

{拼图}
map:array[0..5,0..5] of integer =(
	(1,2,3,10,17,26),
	(4,5,6,11,18,27),
	(7,8,9,12,19,28),
	(13,14,14,16,20,29),
	(21,22,23,24,25,30),
	(31,32,33,34,35,36)
	);

{播放wav声音}
function sndPlaySound(lpszSoundName: PAnsiChar; uFlags: UINT): boolean; stdcall;
	external 'winmm' name 'sndPlaySoundA';
{播放背景音乐API}
function mciSendString(lpszCommand: PAnsiChar; lpszReturnstr: PAnsiChar;
	uReturnLength: longint; hwndCallback:longint): longint; stdcall;
	external 'winmm' name 'mciSendStringA';

{检测拼图的文件}
function checkBMP():boolean;
var
	f: file of char;	{文件}
	flag: boolean= false;
	i: longint;
	x,y: longint;
	head:array[0..53] of char; {bmp文件的头部}
begin
	try    { try/except }
		assign(f,bmpfile);
		reset(f);
		for i:=0 to 53 do read(f,head[i]);
		if ((head[0]<>'B')or(head[1]<>'M')) then
		begin
			MessageBox(0,'文件'+bmpfile+'不是BM文件！',nil,mb_ok);
			flag:=false;
			exit;
		end;
		if (ord(head[28])<>24) then
		begin
			MessageBox(0,'文件'+bmpfile+'不是24位的BMP文件！',nil,mb_ok);
			flag:=false;
			exit;
		end;

		x:=ord(head[18])+ord(head[19])*256+ord(head[20])*65536+ord(head[21])*16777216;
		y:=ord(head[22])+ord(head[23])*256+ord(head[24])*65536+ord(head[25])*16777216; 
		if ((x<>240)or(y<>240))then
		begin
			MessageBox(0,'文件'+bmpfile+'的宽x高不是240x240像索的！',nil,mb_ok);
			flag:=false;
			exit;
		end;

		close(f);
		flag:=true;
	except { try/except }
		MessageBox(0,'读取文件'+bmpfile+'出错！',nil,mb_ok);
	end;   { try/except }
	checkBMP:=flag;
end;

{构建窗口的菜单}
function makeMenu():hMenu;
var
	hmenu1, hmenu2: hMenu;
begin { }
	hFormMenu:=CreateMenu();
	hmenu1:=CreateMenu();
	AppendMenu(hmenu1,MF_STRING,IDM_GAME_NEW,'新建(&N)');
	AppendMenu(hmenu1,MF_SEPARATOR,0,'');
	AppendMenu(hmenu1,MF_CHECKED,IDM_GAME_L1,'初级(&B)');
	AppendMenu(hmenu1,MF_UNCHECKED,IDM_GAME_L2,'中级(&I)');
	AppendMenu(hmenu1,MF_UNCHECKED,IDM_GAME_L3,'高级(&E)');
	AppendMenu(hmenu1,MF_UNCHECKED,IDM_GAME_L4,'无聊(&W)');
	AppendMenu(hmenu1,MF_SEPARATOR,0,'');
	AppendMenu(hmenu1,MF_CHECKED,IDM_GAME_MUSIC,'背景音乐(&M)');
	AppendMenu(hFormMenu,MF_POPUP,hmenu1,'游戏(&G)'); 

	hmenu2:=CreateMenu();
	AppendMenu(hmenu2,MF_STRING,IDM_HELP_ABOUT,'关于(&A)');
	AppendMenu(hFormMenu,MF_POPUP,hmenu2,'帮助(&H)');
	makeMenu:= hFormMenu;
end;  

{打乱拼图map数组}
procedure randMap();
var
i,j,m,y,temp:integer;
begin { }
	m:=level+2;
	y:=1;

	y:=1;
	for i := 0 to m-1 do
	for j := 0 to m-1 do
	begin { for }
		map[i,j]:=y;
		inc(y);
	end;  { for }

	for  i := 1 to m*m-1 do
	begin
		y:=Random(m*m-i);
		y:=y+i;
		temp:=map[i div m,i mod m];
		map[i div m,i mod m]:=map[y div m, y mod m];
		map[y div m, y mod m]:=temp;
	end;
end;  
  
{新建游戏}
procedure newGame();
begin
	randMap();
	map[0,0]:=0;
	isMoveOneLeft:=true;
	//sndPlaySound(pchar('sound/newGame.wav'),3);
	isPlaying:=true;
	isWinned:=false;
	SendMessage(hWindow,WM_PAINT,0,0);
end;  

{选择level}
procedure selectLevel(newLevel:longint);
begin
	CheckMenuItem(hFormMenu,IDM_GAME_L1,MF_UNCHECKED);
	CheckMenuItem(hFormMenu,IDM_GAME_L2,MF_UNCHECKED);
	CheckMenuItem(hFormMenu,IDM_GAME_L3,MF_UNCHECKED);
	CheckMenuItem(hFormMenu,IDM_GAME_L4,MF_UNCHECKED);
	CheckMenuItem(hFormMenu,newLevel,MF_CHECKED); 
	case newLevel of
		IDM_GAME_L1: level:=1;
		IDM_GAME_L2: level:=2;
		IDM_GAME_L3: level:=3;
		IDM_GAME_L4: level:=4;
	end;
	newGame();
end;  

{背景音乐}
procedure playMusic(window:hwnd);
begin
	if(bPlayBgMusic)then
	begin
		bPlayBgMusic:=false;
		mciSendString(pchar('stop bgs'),nil,0,0);
		mciSendString('close all',nil,0,0);
		CheckMenuItem(hFormMenu,IDM_GAME_MUSIC,MF_UNCHECKED);
	end
	else
	begin
		bPlayBgMusic:=true;
		mciSendString(pchar('open '+bgsound +' type sequencer alias bgs'),nil,0,0);
		mciSendString(pchar('play bgs notify'),nil,0,window);
		CheckMenuItem(hFormMenu,IDM_GAME_MUSIC,MF_CHECKED);
	end;
end;
  
{关于}
procedure about(window:hwnd);
begin
	MessageBox(window,'Puzzle拼图游戏 v1.0' + chr(13)+ '作者: 狼妹宋天琢' +chr(13)+
					'E-Mail：1559846698@qq.com'+chr(13)+
					'源码1: https://git.oschina.net/lmstz/puzzle.git'+chr(13)+
					'源码2: https://github.com/SongTianZuo/puzzle.git'
					,'puzzle拼图',mb_ok);
end;

{检测获胜}

function checkWin(m:longint):boolean;
var
	i,j:longint;
begin
	for  i:= 0 to m-1 do
	begin { for i}
		for j := 0 to m-1 do
		begin { for j}
			if((i*m+j+1)<> map[i,j] )then
			begin 
				checkWin:=false;
				exit;
			end;  			  
		end;  { for j}
	end;  { for i}
	checkWin:=true;
end;

{检测是否可以移动}
function checkMove(x:longint;y:longint):boolean;
begin
	if(map[x,y]=0)then
		checkMove:=true
	else
		checkMove:=false;
end;

{点击窗体}
procedure click(x:longint;y:longint);
var
	px,py,m,pm,temp:longint;
begin
	if(isPlaying)then
	begin
		m:=level+2;
		pm:=240 div m;

		px:=x-10-340;
		py:=y-10;
		if((px>=0) and (py>=0))then
		begin
			px:= px div pm;
			py:= py div pm;
			
			temp:=px;
			px:=py;
			py:=temp;
			if((px<m) and (py<m))then
			begin {  }
				if((px-1)>=0)then
				begin
					if(checkMove(px-1,py)) then
					begin
						map[px-1,py]:=map[px,py];
						map[px,py]:=0;
						sndPlaySound(pchar(wavMove),3);
						SendMessage(hWindow,WM_PAINT,0,0);
						exit;
					end;
				end;
				if((px+1)<m)then
				begin
					if(checkMove(px+1,py)) then
					begin
						map[px+1,py]:=map[px,py];
						map[px,py]:=0;
						sndPlaySound(pchar(wavMove),3);
						SendMessage(hWindow,WM_PAINT,0,0);
						exit;
					end;
				end;
				if((py-1)>=0)then
				begin
					if(checkMove(px,py-1)) then
					begin
						map[px,py-1]:=map[px,py];
						map[px,py]:=0;
						sndPlaySound(pchar(wavMove),3);
						SendMessage(hWindow,WM_PAINT,0,0);
						exit;
					end;
				end;
				if((py+1)<m)then
				begin
					if(checkMove(px,py+1)) then
					begin
						map[px,py+1]:=map[px,py];
						map[px,py]:=0;
						sndPlaySound(pchar(wavMove),3);
						SendMessage(hWindow,WM_PAINT,0,0);
						exit;
					end;
				end;
				
				if((px=0) and (py=0) and (not(isMoveOneLeft)))then
				begin
					map[0,0]:=0;
					isMoveOneLeft:=true;
					sndPlaySound(pchar(wavMove),3);
					SendMessage(hWindow,WM_PAINT,0,0);
					exit;
				end;
				
			end;  
		end;

		if((px<0) and (py>=0)) then
		begin {  }
			px:= px div pm;
			py:= py div pm;
			if((px=0) and (py=0))then
			begin
				if(map[0,0]=0)then
				begin
					map[0,0]:=1;
					isMoveOneLeft:=false;
					sndPlaySound(pchar(wavMove),3);
					if(checkWin(m))then
					begin 
						isPlaying:=false;
						isWinned:=true;
						sndPlaySound(pchar(wavWin),3);
					end;
					SendMessage(hWindow,WM_PAINT,0,0);
				end;  				  
			end;
		end;  
		  
	end;
end;  {end click}
  

{绘图}
procedure draw(dc:hdc);
var
	bmp,midBMP:hBitmap; {拼图原图handld，内存图}
	mdc,midDC:hdc; {拼图原图dc，内存dc用来画图缓冲}
	m, pm:longint;
	i,j,wi,wj:longint;
	font: hFont;
begin 
	midDC:=CreateCompatibleDC (0);
	midBMP:=CreateCompatibleBitmap(dc,WINDOW_WIDTH,WINDOW_HEIGHT);
	SelectObject(midDC,midBMP);
	
	bmp:=LoadImage(0,pchar(bmpfile),IMAGE_BITMAP,0,0,LR_LOADFROMFILE);
	mdc:=CreateCompatibleDC(dc);
	SelectObject(mdc,bmp);

	SelectObject (midDC,GetStockObject (WHITE_PEN)); //选择白色画笔 
	SelectObject (midDC,GetStockObject (WHITE_BRUSH)); //选择白色画笔 
	Rectangle(midDC,0,0,WINDOW_WIDTH,WINDOW_HEIGHT); //画个大距形像背景

	StretchBlt(midDC,0,0,240,240,mdc,0,0,240,240,SRCCOPY);

	SelectObject (midDC,GetStockObject (BLACK_PEN)); //选择黑色画笔 
	MoveToEx(midDC,250,0,nil);
	LineTo(midDC,250,240);	//中间分划线
	
	m:=level+2;
	pm:=240 div m;
	if( isPlaying)then
		begin {玩着}
			if(isMoveOneLeft)then
				StretchBlt(midDC,340-pm,0,pm,pm,mdc,0,0,pm,pm,SRCCOPY);	
			for i := 0 to m-1 do
			begin { for i}
				for j := 0 to m-1 do
				begin { for j}
					wi:=(map[i,j]-1) div m;
					wj:=(map[i,j]-1) mod m;
					if (map[i,j]<>0) then
						begin
							StretchBlt(midDC,340+j*pm,i*pm,pm,pm,mdc,wj*pm,wi*pm,pm,pm,SRCCOPY);
						end;					
				end;  { for j}
			end;  { for i}
			
			for i := 1 to m+1 do
			begin
				MoveToEx(midDC,340+(i-1)*pm,0,nil);
				LineTo(midDC,340+(i-1)*pm,240);
				MoveToEx(midDC,340,(i-1)*pm,nil);
				LineTo(midDC,340+240,(i-1)*pm);
			end;
			MoveToEx(midDC,340,0,nil);
			LineTo(midDC,340-pm,0);
			LineTo(midDC,340-pm,pm);
			LineTo(midDC,340,pm);
		end {玩着}
	else
		begin{没有正在玩}
			StretchBlt(midDC,340,0,240,240,mdc,0,0,240,240,SRCCOPY);
			for i := 1 to m+1 do
			begin
				MoveToEx(midDC,340+(i-1)*pm,0,nil);
				LineTo(midDC,340+(i-1)*pm,240);
				MoveToEx(midDC,340,(i-1)*pm,nil);
				LineTo(midDC,340+240,(i-1)*pm);
			end;
			if(isWinned)then{已经胜了}
			begin 
				SetBkMode(midDC,TRANSPARENT);
				SetTextColor(midDC,255);
				font:=CreateFont(70,50,0,0,FW_THIN,0,0,0,
					ANSI_CHARSET,OUT_CHARACTER_PRECIS,
					CLIP_CHARACTER_PRECIS,DEFAULT_QUALITY,
					FF_MODERN,'Arial');
					SelectObject(midDC,font);
				TextOut(midDC, 80, 50, PChar('You Win!'),8);
			end;			  
		end;{没有正在玩}
	
	BitBlt(dc,10,10,WINDOW_WIDTH,WINDOW_HEIGHT,midDC,0,0,SRCCOPY);

	DeleteDC(midDC);
	DeleteObject(midBMP);
	DeleteDC(mdc);
end; {end draw}

{消息处理}
function WindowProc(Window: HWnd; AMessage: UINT; WParam : WPARAM;
LParam: LPARAM): LRESULT; stdcall; export;
var
dc: hwnd;
NrMenu :longint;
x,y:longint;
begin
	WindowProc := 0;
	case AMessage of
	wm_paint: {}
		begin
			DefWindowProc(Window, AMessage, WParam, LParam);
			dc:= GetDC(window); 
			draw(dc);
			ReleaseDC(window,dc);

		end;
	WM_COMMAND: {点击}
		begin 
			NrMenu:=WParam and $FFFF;
			case  NrMenu of
				IDM_GAME_NEW: {新游戏}
					newGame(); 
					  
				IDM_GAME_L1:{初级}
					selectLevel(IDM_GAME_L1);
					  
				IDM_GAME_L2:{中级}
					selectLevel(IDM_GAME_L2);

				IDM_GAME_L3:{高级}
					selectLevel(IDM_GAME_L3);

				IDM_GAME_L4:{无聊}
					selectLevel(IDM_GAME_L4);

				IDM_GAME_MUSIC:{背景音乐}
					playMusic(window);

				IDM_HELP_ABOUT:{关于}
					about(window);				
			end;
		end;
	WM_LBUTTONUP:{单击窗体}
		begin { }
			x:= LParam and $FFFF;
			y:=(LParam shr 16) and $FFFF;
			click(x,y);
		end;  
		  
	WM_CREATE: {窗口创建}
		//sndPlaySound(pchar(bgSound),11);
		begin
			hWindow:=window;
			mciSendString(pchar('open '+bgsound +' type sequencer alias bgs'),nil,0,0);
			mciSendString(pchar('play bgs notify'),nil,0,window);
		end;
	MM_MCINOTIFY: {播放一次完毕后}
		begin
			mciSendString(pchar('seek bgs to start'), nil, 0, 0);
			mciSendString(pchar('play bgs notify'),nil,0,window);
		end;

	wm_Destroy: {关闭}
		begin
			PostQuitMessage(0);
			Exit;
		end;
	end;
	WindowProc := DefWindowProc(Window, AMessage, WParam, LParam);
end; {end WindowProc}

{ Main }
var
AMessage : Msg;
var
	menu:hmenu;
begin
	if(not checkBMP()) then exit;
	menu:=makeMenu();
	CForm(WINDOW_WIDTH,WINDOW_HEIGHT,menu,Longint(@WindowProc)); {窗口宽600，高300,菜单，消息处理}
	SetTitle('puzzle拼图游戏 v1.0');
	Randomize;
	while GetMessage(@AMessage, 0, 0, 0) do
	begin
	TranslateMessage(AMessage);
	DispatchMessage(AMessage);
	end;
	Halt(AMessage.wParam);
end.

