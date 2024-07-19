CREATE TYPE wind AS ENUM (
	'東１', '東２', '東３', '東４',
	'南１', '南２', '南３', '南４',
	'西１', '西２', '西３', '西４'
)
CREATE TYPE outcome AS ENUM (
	'DRAW',
	'RON',
	'TSUMO',
	'ABORT'
)
CREATE TYPE limit_value AS ENUM (
	'MANGAN',
	'HANEMAN',
	'BAIMAN',
	'SANBAIMAN',
	'YAKUMAN'
)
CREATE TYPE hand_state AS ENUM (
	'DAMA',
	'OPEN',
	'RIICHI'
)
CREATE TYPE seat AS ENUM (
	'EAST',
	'SOUTH',
	'WEST',
	'NORTH'
)
CREATE TYPE yaku AS ENUM (
	'TSUMO',
	'RIICHI',
	'IPPATSU',
	'CHANKAN',
	'RINSHAN',
	'HAITEI',
	'HOUTEI',
	'PINFU',
	'TANYAO',
	'IIPEIKOU',
	'SEAT TON',
	'SEAT NAN',
	'SEAT SHAA',
	'SEAT PEI',
	'ROUND TON',
	'ROUND NAN',
	'ROUND SHAA',
	'ROUND PEI',
	'HAKU',
	'HATSU',
	'CHUN',
	'DOUBLE RIICHI',
	'CHIITOITSU',
	'CHANTA',
	'ITTSUU',
	'SANSHOKU DOUJUN',
	'SANSHOKU DOUKOU',
	'SANKANTSU',
	'TOITOI',
	'SANANKOU',
	'SHOUSANGEN',
	'HONROUTOU',
	'RYANPEIKOU',
	'JUNCHAN',
	'HONITSU',
	'CHINITSU',
	'TENHOU',
	'CHIIHOU',
	'DAISANGEN',
	'SUUANKOU',
	'SUUANKOU TANKI',
	'TSUIISOU',
	'RYUUIISOU',
	'CHINROUTOU',
	'CHUUREN',
	'9-SIDED CHUUREN',
	'KOKUSHI',
	'13-SIDED KOKUSHI',
	'DAISUUSHI',
	'SHOUSUUSHI',
	'SUUKANTSU',
)

-- DATA STORES

CREATE TABLE keyv(
	k	varchar PRIMARY KEY, -- Used for constants stored in the DB (lobby number, tenhou rules, display data)
	v	json,
)

CREATE TABLE timezones(
	offset		int PRIMARY KEY,
	timezone	varchar,
	dst			boolean,
)

CREATE TABLE clubs(
	id		serial PRIMARY KEY,
	club	varchar,
)

-- LEAGUE INFORMATION

CREATE TABLE seasons(
	id			serial PRIMARY KEY,
	season		varchar,
	long_season	varchar,
	emoji		varchar,
)

CREATE TABLE leagues(
	id				varchar PRIMARY KEY,
	members			int[],
	emoji			varchar,
	color			varchar,
	table_names		varchar[],
	players_champ	int DEFAULT 0,
	players_up		int DEFAULT 0,
	players_down	int DEFAULT 0,
	double_promote	boolean DEFAULT 0,
)

CREATE TABLE weeks(
	id			int PRIMARY KEY,
	dates		varchar,
	start_time	int,
	end_time	int,
	message_id	varchar,
)

CREATE TABLE tables(
	id			serial PRIMARY KEY,
	table_name	varchar,
	channel_id	varchar,
	league_id	varchar references leagues,
	week_id		int references weeks,
	season		varchar references seasons(season),
	members		int[],
	schedules	bson[], -- {timestamp::int {event::varchar, channel_id::varchar, message_id::varchar, ping_time::int}}
)

CREATE TABLE proposals(
	message_id		varchar PRIMARY KEY,
	week_number		int,
	table_name		varchar,
	table_number	int,
	proposal_time	int,
	requester		varchar,
	channel			varchar,
	created			timestamp DEFAULT now(),
)

-- PLAYERS AND RESULTS

CREATE TABLE members(
	id				serial PRIMARY KEY,
	first_name		varchar,
	last_name		varchar,
	display_name	varchar,
	discord_id		varchar,
	club			int references clubs,
	pronouns		varchar,
	stream			varchar,
	tenhou			varchar(8),
	tenhou_history	varchar(8)[],
	timezone		int references timezones,
	penalty			int,
)

CREATE TABLE games(
	id			serial PRIMARY KEY,
	log_uuid	varchar,
	season		varchar references seasons(season),
	league		varchar references leagues,
	total_hands	int,
	total_time	int,
	game_time	timestamp NOT NULL DEFAULT now(),
)

CREATE TABLE game_players(
	id				serial PRIMARY KEY,
	game_id			int references games ON DELETE CASCADE,
	member_id		int references members,
	starting_seat	seat,
	place			int,
	final_score		int,
	final_uma		int,
	final_points	int,
)

CREATE TABLE game_hands(
	id			serial PRIMARY KEY,
	game_id		int references games ON DELETE CASCADE,
	round		wind,
	honba		int,
	pot_sticks	int,
	dealer		int references game_players,
	dora_tiles	int[],
	ura_tiles	int[],
	outcome		outcome,
)

CREATE TABLE player_hands(
	id				serial PRIMARY KEY,
	member_id		int references members,
	hand_id			int references game_hands ON DELETE CASCADE,
	start_score		int,
	haipai_tiles	int[],
	haipai_shanten	int,
	draws			int[], -- Negative if called, see calls
	discards		int[],
	ending_tiles	int[],
	calls			json, -- {called::int, shown::int[], from::int}
	ending_shanten	int,
	hand_state		hand_state,
	was_tenpai		boolean,
	tenpai_turn		int,
	riichi_turn		int,
	agari_turn		int,
	tsumogiri_count	int,
	tedashi_count	int,
)

CREATE TABLE agaris(
	id				serial PRIMARY KEY,
	hand_id			int references game_hands ON DELETE CASCADE,
	agari_tile		int,
	agari_hand		int[13],
	han				int,
	fu				int,
	points			int,
	limit_value		limit_value,
	yaku			yaku[],
	dora_count		int,
	ura_count		int,
	winner_id		int references members,
	winner_turn		int,
	loser_id		int references members,
	loser_shanten	int,
)

-- STATS

-- One stats record for each member for each season, contains totals

CREATE TABLE stats(
    id 			serial PRIMARY KEY,
    member 		int references members,
    season 		varchar references seasons(season),
	league 		varchar references leagues,
	games 		int DEFAULT 0,
	place_1 	int DEFAULT 0,
	place_2 	int DEFAULT 0,
	place_3 	int DEFAULT 0,
	place_4 	int DEFAULT 0,
	place_avg	real GENERATED ALWAYS AS (
		((place_1) + (place_2 * 2) + (place_3 * 3) + (place_4 * 4)) / 4
	) STORED,
	uma			int DEFAULT 0,
	
	-- Round based
	starting_shanten	int DEFAULT 0,
	total_rounds 		int DEFAULT 0,
	rounds_as_dealer 	int DEFAULT 0,
	oyakaburi_times 	int DEFAULT 0,
	oyakaburi_value 	int DEFAULT 0,
	total_time 			int DEFAULT 0,
	timed_rounds 		int DEFAULT 0,

	-- Discard based
	discards_tsumogiri 		int DEFAULT 0,
	discards_tedashi 		int DEFAULT 0,
	discards_total 			int DEFAULT 0,
	discards_to_iishan_eff	int DEFAULT 0,
	discards_to_iishan		int DEFAULT 0,
	total_wait_tiles 		int DEFAULT 0,
	riichi_wait_tiles 		int DEFAULT 0,

	-- Yaku and han
	yaku_obtained 		int[27] NOT NULL,
	yaku_obtained_count	int	GENERATED ALWAYS AS (cardinality(array_remove(yaku_obtained, 0))) STORED,
	yaku_seen 			int[27] NOT NULL,
	yaku_seen_count		int GENERATED ALWAYS AS (cardinality(array_remove(yaku_seen, 0))) STORED,
	yakuman_obtained	yaku[],
	yakuman_count		int GENERATED ALWAYS AS (cardinality(yakuman_obtained)) STORED,
	yakuman_seen		int DEFAULT 0,
	han_win_totals 		int[14] NOT NULL,
	han_loss_totals 	int[14] NOT NULL,
	fu 					int[12] NOT NULL,
	fu_total			int GENERATED ALWAYS AS (
		(fu[1]::integer * 20) + (fu[2]::integer * 25) + (fu[3]::integer * 30) +
		(fu[4]::integer * 40) + (fu[5]::integer * 50) + (fu[6]::integer * 60) +
		(fu[7]::integer * 70) + (fu[8]::integer * 80) + (fu[9]::integer * 90) +
		(fu[10]::integer * 100) + (fu[11]::integer * 110) + (fu[12]::integer * 120)
	) STORED,
	limit_win_totals 	int[6] NOT NULL,
	limit_loss_totals 	int[6] NOT NULL,

	-- Hand state: open
	open_win_tsumo 		int DEFAULT 0,
	open_win_ron 		int DEFAULT 0,
	open_win_count		int GENERATED ALWAYS AS (open_win_tsumo + open_win_ron) STORED,
	open_win_value 		int DEFAULT 0,
	open_win_dora 		int DEFAULT 0,
	open_win_turns 		int DEFAULT 0,
	open_draw_tenpai 	int DEFAULT 0,
	open_draw_noten 	int DEFAULT 0,
	open_draw_count		int GENERATED ALWAYS AS (open_draw_tenpai + open_draw_noten) STORED,
	open_neutral 		int DEFAULT 0,
	open_loss_tsumo 	int DEFAULT 0,
	open_loss_ron 		int DEFAULT 0,
	open_loss_count		int GENERATED ALWAYS AS (open_loss_tsumo + open_loss_ron) STORED,
	open_loss_value 	int DEFAULT 0,
	open_loss_shanten 	int DEFAULT 0,
	open_tenpai_turns 	int DEFAULT 0,
	open_tenpai_hands 	int DEFAULT 0,
	open_count			int GENERATED ALWAYS AS (open_win_count + open_draw_count + open_neutral + open_loss_count) STORED,

	-- Hand state: dama
	dama_win_tsumo 		int DEFAULT 0,
	dama_win_ron 		int DEFAULT 0,
	dama_win_count		int GENERATED ALWAYS AS (dama_win_tsumo + dama_win_ron) STORED,
	dama_win_value 		int DEFAULT 0,
	dama_win_dora 		int DEFAULT 0,
	dama_win_turns 		int DEFAULT 0,
	dama_draw_tenpai 	int DEFAULT 0,
	dama_draw_noten 	int DEFAULT 0,
	dama_draw_count		int GENERATED ALWAYS AS (dama_draw_tenpai + dama_draw_noten) STORED,
	dama_neutral 		int DEFAULT 0,
	dama_loss_tsumo 	int DEFAULT 0,
	dama_loss_ron 		int DEFAULT 0,
	dama_loss_count		int GENERATED ALWAYS AS (dama_loss_tsumo + dama_loss_ron) STORED,
	dama_loss_value 	int DEFAULT 0,
	dama_loss_shanten 	int DEFAULT 0,
	dama_tenpai_turns 	int DEFAULT 0,
	dama_tenpai_hands 	int DEFAULT 0,
	dama_count			int GENERATED ALWAYS AS (dama_win_count + dama_draw_count + dama_neutral + dama_loss_count) STORED,

	-- Hand state: riichi
	riichi_win_tsumo 		int DEFAULT 0,
	riichi_win_ron 			int DEFAULT 0,
	riichi_win_count		int GENERATED ALWAYS AS (riichi_win_tsumo + riichi_win_ron) STORED,
	riichi_win_value 		int DEFAULT 0,
	riichi_win_dora 		int DEFAULT 0,
	riichi_win_ura			int DEFAULT 0,
	riichi_win_turns 		int DEFAULT 0,
	riichi_draw_tenpai 		int DEFAULT 0,
	riichi_draw_noten 		int DEFAULT 0,
	riichi_draw_count		int GENERATED ALWAYS AS (riichi_draw_tenpai + riichi_draw_noten) STORED,
	riichi_neutral 			int DEFAULT 0,
	riichi_loss_tsumo 		int DEFAULT 0,
	riichi_loss_ron 		int DEFAULT 0,
	riichi_loss_count		int GENERATED ALWAYS AS (riichi_loss_tsumo + riichi_loss_ron) STORED,
	riichi_loss_value 		int DEFAULT 0,
	riichi_loss_shanten 	int DEFAULT 0,
	riichi_tenpai_turns 	int DEFAULT 0,
	riichi_tenpai_hands 	int DEFAULT 0,
	riichi_count			int GENERATED ALWAYS AS (riichi_win_count + riichi_draw_count + riichi_neutral + riichi_loss_count) STORED,

	-- Aggregates
	total_win_tsumo			int GENERATED ALWAYS AS (open_win_tsumo + dama_win_tsumo + riichi_win_tsumo) STORED,
	total_win_ron			int GENERATED ALWAYS AS (open_win_ron + dama_win_ron + riichi_win_ron) STORED,
	total_win_count			int GENERATED ALWAYS AS (
		open_win_tsumo + dama_win_tsumo + riichi_win_tsumo +
		open_win_ron + dama_win_ron + riichi_win_ron
	) STORED,
	total_win_value			int GENERATED ALWAYS AS (open_win_value + dama_win_value + riichi_win_value) STORED,
	total_win_dora			int GENERATED ALWAYS AS (open_win_dora + dama_win_dora + riichi_win_dora) STORED,
	total_win_turns			int GENERATED ALWAYS AS (open_win_turns + dama_win_turns + riichi_win_turns) STORED,
	total_draw_tenpai		int GENERATED ALWAYS AS (open_draw_tenpai + dama_draw_tenpai + riichi_draw_tenpai) STORED,
	total_draw_noten		int GENERATED ALWAYS AS (open_draw_noten + dama_draw_noten + riichi_draw_noten) STORED,
	total_draw_count		int GENERATED ALWAYS AS (
		open_draw_tenpai + dama_draw_tenpai + riichi_draw_tenpai +
		open_draw_noten + dama_draw_noten + riichi_draw_noten
	) STORED,
	total_neutral			int GENERATED ALWAYS AS (open_neutral + dama_neutral + riichi_neutral) STORED,
	total_loss_tsumo		int GENERATED ALWAYS AS (open_loss_tsumo + dama_loss_tsumo + riichi_loss_tsumo) STORED,
	total_loss_ron			int GENERATED ALWAYS AS (open_loss_ron + dama_loss_ron + riichi_loss_ron) STORED,
	total_loss_count		int GENERATED ALWAYS AS (
		open_loss_tsumo + dama_loss_tsumo + riichi_loss_tsumo +
		open_loss_ron + dama_loss_ron + riichi_loss_ron
	) STORED,
	total_loss_value		int GENERATED ALWAYS AS (open_loss_value + dama_loss_value + riichi_loss_value) STORED,
	total_loss_shanten		int GENERATED ALWAYS AS (open_loss_shanten + dama_loss_shanten + riichi_loss_shanten) STORED,
	total_tenpai_turns		int GENERATED ALWAYS AS (open_tenpai_turns + dama_tenpai_turns + riichi_tenpai_turns) STORED,
	total_tenpai_hands		int GENERATED ALWAYS AS (open_tenpai_hands + dama_tenpai_hands + riichi_tenpai_hands) STORED,
)

-- TO ADD: Views for totals of {season, league}, {season}, {member}, {*}