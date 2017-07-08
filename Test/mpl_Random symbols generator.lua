
s = ''
t = {'a','e', 'i', 'o', 'u', 'y'}
for i = 1, 200 do
  prob = 0.3
  if math.random() > prob then
    s = s..t[math.floor(math.random()*5) + 1]
   else
    s = s..string.char(math.floor(math.random()*26+65))
  end
end


reaper.ClearConsole()
reaper.ShowConsoleMsg(s)
