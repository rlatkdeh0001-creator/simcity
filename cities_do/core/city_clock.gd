extends RefCounted
const REAL_SECONDS_PER_DAY := 3600.0
const DAYS_PER_YEAR := 12
const GAME_SECONDS_PER_DAY := 86400.0
const SCALE := GAME_SECONDS_PER_DAY/REAL_SECONDS_PER_DAY
const COMMUTE_START := 5
const COMMUTE_END := 9
signal minute_changed
signal day_changed(previous: int,current: int)
var game_seconds := 0.0:
 set(value):
  var previous_minute:=floori(game_seconds/60)
  var previous_day:=day()
  game_seconds=value
  if floori(game_seconds/60)!=previous_minute:minute_changed.emit()
  if day()!=previous_day:day_changed.emit(previous_day,day())
func advance_real(seconds: float) -> void:
 if is_finite(seconds) and seconds>0:game_seconds+=seconds*SCALE
func day() -> int:return floori(game_seconds/GAME_SECONDS_PER_DAY)
func year() -> int:return day()/DAYS_PER_YEAR+1
func hour() -> float:return fmod(game_seconds/GAME_SECONDS_PER_DAY,1.0)*24
func commuting() -> bool:return hour()>=COMMUTE_START and hour()<COMMUTE_END
func caption() -> String:
 return "%d년 %d일 %02d:%02d" % [year(),day()%DAYS_PER_YEAR+1,int(hour()),int(fmod(game_seconds/60,60))]
