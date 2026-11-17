extends Control
## Approved A2 presentation. Reads published scalars only; commands carry a complete policy.
const Money=preload("res://core/currency_label.gd")
const Economy=preload("res://core/economy_config.gd")
const COLORS=[Color("3fbf6a"),Color("36b7ff"),Color("f2c14e"),Color("9fb3bb"),Color("ff7a7a"),Color("b85c5c")]
signal closed
var city
var panel:PanelContainer
var scroll:ScrollContainer
var close_button:Button
var tabs:Array[Button]=[]
var sliders:Array[HSlider]=[]
var rate_labels:Array[Label]=[]
var amounts:Array[Label]=[]
var values:Dictionary={}
var bars:Dictionary={}
var net:Label
var loan:HSlider
var loan_limit:Label
var pending_loan:Variant=null
var pending_loan_tick:=0
var pending_rates:Array=[]
var pending_publication_tick:=0
var snapshot:Dictionary={}
var refresh_count:=0
func skin(color:Color)->StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=Color("38515e");s.set_border_width_all(1);s.set_corner_radius_all(10)
 s.content_margin_left=18;s.content_margin_right=18;s.content_margin_top=14;s.content_margin_bottom=14
 return s
func text(parent:Node,caption:String,pixels:int=18)->Label:
 var l:=Label.new();l.text=caption;l.add_theme_font_size_override("font_size",pixels);parent.add_child(l);return l
func money(parent:Node,pixels:int=18)->Label:
 var l:=Money.new();l.text="—";l.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;l.add_theme_font_size_override("font_size",pixels);parent.add_child(l);return l
func _ready():
 name="BudgetWindow";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var shade:=ColorRect.new();shade.color=Color(0,0,0,.45);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.offset_left=24;panel.offset_right=-24;panel.offset_top=20;panel.offset_bottom=-112;panel.add_theme_stylebox_override("panel",skin(Color("142b37")))
 var frame:=HBoxContainer.new();frame.add_theme_constant_override("separation",20);panel.add_child(frame)
 var navigation:=VBoxContainer.new();navigation.custom_minimum_size.x=120;frame.add_child(navigation)
 for caption in ["예산","교역","물자","정책"]:
  var button:=Button.new();button.text=caption;button.custom_minimum_size.y=52;button.disabled=caption!="예산";navigation.add_child(button);tabs.append(button)
  if caption=="예산":button.add_theme_stylebox_override("normal",skin(Color("236389")))
 frame.add_child(VSeparator.new())
 var main:=VBoxContainer.new();main.size_flags_horizontal=Control.SIZE_EXPAND_FILL;main.add_theme_constant_override("separation",18);frame.add_child(main)
 var header:=HBoxContainer.new();main.add_child(header)
 text(header,"예산",26).size_flags_horizontal=Control.SIZE_EXPAND_FILL
 net=money(header,28)
 close_button=Button.new();close_button.name="CloseBudget";close_button.text="×";close_button.tooltip_text="닫기 (Esc)";close_button.custom_minimum_size=Vector2(46,46);header.add_child(close_button);close_button.pressed.connect(close)
 main.add_child(HSeparator.new())
 scroll=ScrollContainer.new();scroll.follow_focus=true;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(scroll)
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",24);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 var grid:=GridContainer.new();grid.columns=4;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",28);body.add_child(grid)
 text(grid,"")
 for caption in ["1·2단계","3·4단계","5단계"]:text(grid,caption,20)
 for z in range(3):
  var title:=text(grid,["주거","상업","공업"][z],22);title.add_theme_color_override("font_color",COLORS[z]);title.custom_minimum_size.x=64
  for band in range(3):
   var index:=z*3+band
   var cell:=VBoxContainer.new();cell.custom_minimum_size=Vector2(160,130);cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cell.add_theme_constant_override("separation",14);grid.add_child(cell)
   var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);cell.add_child(row)
   var rate:=text(row,"—",28);rate.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rate_labels.append(rate)
   amounts.append(money(row))
   var slider:=HSlider.new();slider.name="TaxRate%d"%index;slider.min_value=0;slider.max_value=20;slider.step=1;slider.custom_minimum_size.y=36;slider.value_changed.connect(change_rate.bind(index));cell.add_child(slider);sliders.append(slider)
 body.add_child(VSeparator.new())
 var side:=VBoxContainer.new();side.custom_minimum_size.x=300;side.add_theme_constant_override("separation",10);body.add_child(side)
 text(side,"수입",20);composition(side,"income",[0,1,2,3])
 for item in [["residential","주거세"],["commercial","상업세"],["industrial","공업세"],["utility_income","전기·수도"],["income","합계"]]:value_row(side,item[0],item[1])
 side.add_child(HSeparator.new());text(side,"지출",20);composition(side,"expenses",[4,3,5])
 for item in [["upkeep","시설 유지비"],["utility_expense","전기·수도"],["interest","대출 이자"],["expenses","합계"]]:value_row(side,item[0],item[1])
 side.add_child(HSeparator.new());value_row(side,"loan","대출")
 loan=HSlider.new();loan.custom_minimum_size.y=36;loan.value_changed.connect(change_loan);loan.gui_input.connect(loan_input);loan.scrollable=false;side.add_child(loan)
 loan_limit=money(side)
 var focusable:Array=[tabs[0],close_button];focusable.append_array(sliders)
 focusable.append(loan)
 for i in range(focusable.size()):
  focusable[i].focus_next=focusable[(i+1)%focusable.size()].get_path();focusable[i].focus_previous=focusable[posmod(i-1,focusable.size())].get_path()
  focusable[i].focus_neighbor_top=focusable[i].focus_previous;focusable[i].focus_neighbor_bottom=focusable[i].focus_next
  focusable[i].focus_neighbor_left=focusable[i].get_path() if focusable[i] is HSlider else focusable[i].focus_previous
  focusable[i].focus_neighbor_right=focusable[i].get_path() if focusable[i] is HSlider else focusable[i].focus_next
 hide()
func value_row(parent:Node,key:String,caption:String):
 var row:=HBoxContainer.new();parent.add_child(row);text(row,caption).size_flags_horizontal=Control.SIZE_EXPAND_FILL;values[key]=money(row)
func composition(parent:Node,key:String,colors:Array):
 var background:=PanelContainer.new();background.add_theme_stylebox_override("panel",skin(Color("1c3846")));parent.add_child(background)
 # Zero-margin bar background keeps a genuine zero total empty, not a fake segment.
 var s:=StyleBoxFlat.new();s.bg_color=Color("1c3846");background.add_theme_stylebox_override("panel",s)
 var row:=HBoxContainer.new();row.custom_minimum_size.y=14;row.add_theme_constant_override("separation",0);background.add_child(row);bars[key]=[]
 for index in colors:
  var segment:=ColorRect.new();segment.color=COLORS[index];segment.mouse_filter=Control.MOUSE_FILTER_IGNORE;segment.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(segment);bars[key].append(segment);segment.hide()
func bind_model(model):
 if city==model:return
 disconnect_model();city=model;pending_rates.clear();pending_publication_tick=0;pending_loan=null;pending_loan_tick=0;snapshot.clear()
 if city!=null:
  city.economic_changed.connect(refresh);city.society_changed.connect(refresh)
 refresh()
func disconnect_model():
 if city==null:return
 for event in ["economic_changed","society_changed"]:
  if city.is_connected(event,refresh):city.disconnect(event,refresh)
func _exit_tree():disconnect_model()
func open(model):
 bind_model(model);show();refresh();close_button.grab_focus()
func close():
 hide();closed.emit()
func change_rate(value:float,index:int):
 if city==null:return
 if pending_rates.is_empty():pending_rates=city.tax_status().get("policy",{}).get("rates",[]).duplicate()
 if pending_rates.size()!=9:return
 pending_rates[index]=int(value)
 # Replay acknowledgment is not publication; financing may split the FIFO.
 pending_publication_tick=0
 if city.simulation!=null:
  pending_publication_tick=city.simulation.edit_publication_tick()
 var result:Dictionary=city.configure_tax_policy({"rates":pending_rates.duplicate()})
 if not result.get("ok",false) and not result.get("queued",false):pending_rates.clear()
 snapshot.clear();refresh()
func change_loan(value:float):
 if city==null:return
 var debt:Dictionary=city.loan_status()
 # Preserve exact outstanding fractional principal in Range; quantize only user intents.
 value=clampf(roundf(value/float(debt.slider_step))*float(debt.slider_step),0.0,debt.limit)
 pending_loan=value;pending_loan_tick=0
 if city.simulation!=null:
  pending_loan_tick=city.simulation.edit_publication_tick(true)
 var result:Dictionary=city.set_loan_amount(value)
 if not result.get("ok",false) and not result.get("queued",false):pending_loan=null
 snapshot.clear();refresh()
func loan_input(event:InputEvent):
 if not loan.editable or city==null:return
 if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT]:
  loan.accept_event()
  change_loan(loan.value+float(city.loan_status().slider_step)*(-1 if event.keycode==KEY_LEFT else 1))
func put(label:Label,value:String):
 if label.text!=value:label.text=value
func amount(value:Variant)->String:
 return "—" if value==null else Economy.format_amount(roundi(float(value)))
func refresh():
 if not visible or city==null or net==null:return
 var tax:Dictionary=city.tax_status();var economic:Dictionary=city.economic_status()
 var debt:Dictionary=city.loan_status()
 if pending_loan!=null and (city.simulation==null or city.simulation.get_published_tick()>=pending_loan_tick):pending_loan=null
 var rates:Array=tax.get("policy",{}).get("rates",[])
 # Check the publication fence before the display cache: equal scalar values
 # may still be a newer acknowledgment, including after close/reopen.
 # The fence includes every queued financing barrier, so reaching it also
 # reconciles an authoritative rejection/adjustment; older equal values cannot ack.
 if not pending_rates.is_empty() and (city.simulation==null or city.simulation.get_published_tick()>=pending_publication_tick):pending_rates.clear()
 var state:Dictionary={"tax":tax,"economic":economic,"pending":pending_rates.duplicate(),"debt":debt,"pending_loan":pending_loan}
 if state==snapshot:return
 snapshot=state.duplicate(true);refresh_count+=1

 for i in range(9):
  var valid:=rates.size()==9
  var displayed_rates:Array=pending_rates if pending_rates.size()==9 else rates
  put(rate_labels[i],"%d%%"%int(displayed_rates[i]) if valid else "—")
  sliders[i].editable=valid and not debt.bankrupt
  if valid:sliders[i].set_value_no_signal(displayed_rates[i])
  sliders[i].tooltip_text=""
  var cells:Array=tax.get("cells",[]);var days:=int(tax.get("days",0))
  put(amounts[i],amount(float(cells[i].collected)/days) if days>0 and cells.size()==9 else "—")
 var available:bool=economic.get("available",false)
 var daily=economic.get("daily_net")
 put(net,"—" if not available else ("−" if roundi(daily)<0 else "+")+Economy.format_amount(absi(roundi(daily)))+"/월")
 net.add_theme_color_override("font_color",Color("edf4f5") if not available else (COLORS[4] if daily<0 else COLORS[0]))
 var entries:Dictionary={}
 if available:
  var days:=int(tax.get("days",0));var zones:Dictionary=tax.get("zones",{})
  for key in ["residential","commercial","industrial"]:entries[key]=float(zones[key].collected)/days if days>0 and zones.has(key) else null
  entries.utility_income=economic.power_revenue+economic.water_revenue;entries.utility_expense=economic.power_expense+economic.water_expense
  entries.upkeep=economic.facility_upkeep;entries.interest=economic.interest
  entries.income=economic.tax_collected+entries.utility_income;entries.expenses=entries.upkeep+entries.utility_expense+entries.interest
 for key in values:put(values[key],amount(entries.get(key)))
 put(values.loan,amount(debt.principal));put(loan_limit,amount(debt.limit))
 loan.editable=not debt.bankrupt
 loan.set_block_signals(true)
 loan.max_value=maxf(debt.limit,debt.principal);loan.step=0.0
 loan.set_value_no_signal(float(pending_loan) if pending_loan!=null else debt.principal)
 loan.set_block_signals(false)
 loan.tooltip_text="적용 대기" if pending_loan!=null else ("파산 · 게임 오버" if debt.bankrupt else str(debt.last_command_result.get("reason","")))
 update_bar("income",[entries.get("residential"),entries.get("commercial"),entries.get("industrial"),entries.get("utility_income")])
 update_bar("expenses",[entries.get("upkeep"),entries.get("utility_expense"),entries.get("interest")])
func update_bar(key:String,parts:Array):
 for i in range(parts.size()):
  var segment:ColorRect=bars[key][i];var value:float=0 if parts[i]==null else maxf(0,float(parts[i]))
  segment.visible=value>0;segment.size_flags_stretch_ratio=maxf(.0001,value)
