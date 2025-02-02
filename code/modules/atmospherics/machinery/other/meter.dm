/obj/machinery/atmospherics/meter
	name = "gas flow meter"
	desc = "It measures something."
	icon = 'icons/obj/meter.dmi'
	icon_state = "meterX"

	layer = GAS_PUMP_LAYER

	var/obj/machinery/atmospherics/pipe/target = null
	anchored = TRUE
	max_integrity = 150
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 100, BOMB = 0, BIO = 100, RAD = 100, FIRE = 40, ACID = 0)
	power_channel = ENVIRON
	frequency = ATMOS_DISTRO_FREQ
	var/id_tag
	use_power = IDLE_POWER_USE
	idle_power_usage = 2
	active_power_usage = 5
	req_one_access_txt = "24;10"
	Mtoollink = TRUE
	settagwhitelist = list("id_tag")

	serialize()
		var/list/data = ..()
		data["id_tag"] = id_tag
		return data

	deserialize(list/data)
		id_tag = data["id_tag"]
		settagwhitelist = list("id_tag")
		..()

/obj/machinery/atmospherics/meter/Initialize(mapload)
	. = ..()
	target = locate(/obj/machinery/atmospherics/pipe) in loc

/obj/machinery/atmospherics/meter/Destroy()
	target = null
	return ..()

/obj/machinery/atmospherics/meter/detailed_examine()
	return "Measures the volume and temperature of the pipe under the meter."

/obj/machinery/atmospherics/meter/process_atmos()
	if(!target || (stat & (BROKEN|NOPOWER)))
		update_icon(UPDATE_ICON_STATE)
		return

	var/datum/gas_mixture/environment = target.return_air()
	if(!environment)
		update_icon(UPDATE_ICON_STATE)
		return

	update_icon(UPDATE_ICON_STATE)
	var/env_pressure = environment.return_pressure()
	if(frequency)
		var/datum/radio_frequency/radio_connection = SSradio.return_frequency(frequency)

		if(!radio_connection) return

		var/datum/signal/signal = new
		signal.source = src
		signal.transmission_method = 1
		signal.data = list(
			"tag" = id_tag,
			"device" = "AM",
			"pressure" = round(env_pressure),
			"sigtype" = "status"
		)
		radio_connection.post_signal(src, signal)


/obj/machinery/atmospherics/meter/update_icon_state()
	if(!target)
		icon_state = "meterX"
		return

	if(stat & (BROKEN|NOPOWER))
		icon_state = "meter0"
		return

	var/datum/gas_mixture/environment = target.return_air()
	if(!environment)
		icon_state = "meterX"
		return

	var/env_pressure = environment.return_pressure()
	if(env_pressure <= 0.15*ONE_ATMOSPHERE)
		icon_state = "meter0"
	else if(env_pressure <= 1.8*ONE_ATMOSPHERE)
		var/val = round(env_pressure/(ONE_ATMOSPHERE*0.3) + 0.5)
		icon_state = "meter1_[val]"
	else if(env_pressure <= 30*ONE_ATMOSPHERE)
		var/val = round(env_pressure/(ONE_ATMOSPHERE*5)-0.35) + 1
		icon_state = "meter2_[val]"
	else if(env_pressure <= 59*ONE_ATMOSPHERE)
		var/val = round(env_pressure/(ONE_ATMOSPHERE*5) - 6) + 1
		icon_state = "meter3_[val]"
	else
		icon_state = "meter4"

/obj/machinery/atmospherics/meter/proc/status()
	var/t = ""
	if(target)
		var/datum/gas_mixture/environment = target.return_air()
		if(environment)
			t += "The pressure gauge reads [round(environment.return_pressure(), 0.01)] kPa; [round(environment.temperature,0.01)]&deg;K ([round(environment.temperature-T0C,0.01)]&deg;C)"
		else
			t += "The sensor error light is blinking."
	else
		t += "The connect error light is blinking."
	return t

/obj/machinery/atmospherics/meter/examine(mob/user)
	var/t = "A gas flow meter. "

	if(get_dist(user, src) > 3 && !(isAI(user) || istype(user, /mob/dead)))
		t += "<span class='boldnotice'>You are too far away to read it.</span>"

	else if(stat & (NOPOWER|BROKEN))
		t += "<span class='danger'>The display is off.</span>"

	else if(target)
		var/datum/gas_mixture/environment = target.return_air()
		if(environment)
			t += "The pressure gauge reads [round(environment.return_pressure(), 0.01)] kPa; [round(environment.temperature,0.01)]K ([round(environment.temperature-T0C,0.01)]&deg;C)"
		else
			t += "The sensor error light is blinking."
	else
		t += "The connect error light is blinking."

	. = list(t)

/obj/machinery/atmospherics/meter/Click()
	if(isAI(usr)) // ghosts can call ..() for examine
		usr.examinate(src)
		return 1

	return ..()

/obj/machinery/atmospherics/meter/attackby(obj/item/W as obj, mob/user as mob, params)
	if(istype(W, /obj/item/multitool))
		update_multitool_menu(user)
		return 1

	if(!istype(W, /obj/item/wrench))
		return ..()
	playsound(loc, W.usesound, 50, 1)
	to_chat(user, "<span class='notice'>You begin to unfasten \the [src]...</span>")
	if(do_after(user, 40 * W.toolspeed, target = src))
		user.visible_message( \
			"[user] unfastens \the [src].", \
			"<span class='notice'>You have unfastened \the [src].</span>", \
			"You hear ratchet.")
		deconstruct(TRUE)

/obj/machinery/atmospherics/meter/deconstruct(disassembled = TRUE)
	if(!(flags & NODECONSTRUCT))
		new /obj/item/pipe_meter(loc)
	qdel(src)

/obj/machinery/atmospherics/meter/singularity_pull(S, current_size)
	..()
	if(current_size >= STAGE_FIVE)
		deconstruct()

/obj/machinery/atmospherics/meter/multitool_menu(mob/user, obj/item/multitool/P)
	return {"
	<b>Main</b>
	<ul>
		<li><b>Frequency:</b> <a href="?src=[UID()];set_freq=-1">[format_frequency(frequency)] GHz</a> (<a href="?src=[UID()];set_freq=[initial(frequency)]">Reset</a>)</li>
		<li>[format_tag("ID Tag","id_tag")]</li>
	</ul>"}
