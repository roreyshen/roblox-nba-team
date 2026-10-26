--!nonstrict
-- Every team-season you can roll. Season year = the year the season ended (1996 = 1995-96).
-- Roster rows: { name, positions ("SF/SG" = plays both), rating }
-- Max 8 players per season (the draft screen shows up to 8 cards).

export type Player = {
	name: string,
	positions: { string },
	posText: string,
	ovr: number,
	teamKey: string,
	teamLabel: string,
	shortLabel: string,
	franchise: string,
}

export type Era = {
	key: string,
	franchise: string,
	year: number,
	label: string,
	shortLabel: string,
	color: { number },
	weight: number,
	players: { Player },
}

export type Franchise = {
	id: string,
	city: string,
	name: string,
	color: { number },
	eras: { Era },
}

local RAW: { any } = {
	{ id = "Bulls", city = "Chicago", name = "Bulls", color = { 206, 17, 65 }, eras = {
		{ year = 1991, roster = {
			{ "Michael Jordan", "SG", 98 }, { "Scottie Pippen", "SF/SG", 90 }, { "Horace Grant", "PF", 84 },
			{ "B.J. Armstrong", "PG", 78 }, { "John Paxson", "PG", 77 }, { "Bill Cartwright", "C", 77 },
			{ "Craig Hodges", "SG", 73 }, { "Stacey King", "PF/C", 72 },
		} },
		{ year = 1996, roster = {
			{ "Michael Jordan", "SG", 99 }, { "Scottie Pippen", "SF", 94 }, { "Dennis Rodman", "PF", 88 },
			{ "Toni Kukoc", "SF/PF", 84 }, { "Ron Harper", "PG/SG", 79 }, { "Steve Kerr", "PG", 78 },
			{ "Luc Longley", "C", 77 }, { "Bill Wennington", "C", 72 },
		} },
	} },
	{ id = "Lakers", city = "Los Angeles", name = "Lakers", color = { 85, 37, 130 }, eras = {
		{ year = 1987, roster = {
			{ "Magic Johnson", "PG", 97 }, { "Kareem Abdul-Jabbar", "C", 89 }, { "James Worthy", "SF", 89 },
			{ "Byron Scott", "SG", 84 }, { "A.C. Green", "PF", 80 }, { "Michael Cooper", "SG/SF", 80 },
			{ "Mychal Thompson", "C/PF", 78 }, { "Kurt Rambis", "PF", 72 },
		} },
		{ year = 2001, roster = {
			{ "Shaquille O'Neal", "C", 98 }, { "Kobe Bryant", "SG", 94 }, { "Robert Horry", "PF", 80 },
			{ "Derek Fisher", "PG", 78 }, { "Rick Fox", "SF", 78 }, { "Horace Grant", "PF", 77 },
			{ "Ron Harper", "PG", 74 }, { "Brian Shaw", "PG/SG", 74 },
		} },
		{ year = 2009, roster = {
			{ "Kobe Bryant", "SG", 96 }, { "Pau Gasol", "PF/C", 89 }, { "Lamar Odom", "PF/SF", 83 },
			{ "Andrew Bynum", "C", 82 }, { "Trevor Ariza", "SF", 79 }, { "Derek Fisher", "PG", 77 },
			{ "Shannon Brown", "SG", 74 }, { "Jordan Farmar", "PG", 73 },
		} },
		{ year = 2020, roster = {
			{ "LeBron James", "SF/PG", 97 }, { "Anthony Davis", "PF/C", 95 }, { "Kentavious Caldwell-Pope", "SG", 79 },
			{ "Danny Green", "SG/SF", 78 }, { "Kyle Kuzma", "PF", 78 }, { "Rajon Rondo", "PG", 77 },
			{ "Dwight Howard", "C", 77 }, { "Alex Caruso", "PG/SG", 77 },
		} },
	} },
	{ id = "Celtics", city = "Boston", name = "Celtics", color = { 0, 122, 51 }, eras = {
		{ year = 1986, roster = {
			{ "Larry Bird", "SF", 98 }, { "Kevin McHale", "PF", 91 }, { "Robert Parish", "C", 87 },
			{ "Dennis Johnson", "PG", 83 }, { "Danny Ainge", "SG", 82 }, { "Bill Walton", "C", 80 },
			{ "Scott Wedman", "SF", 74 }, { "Jerry Sichting", "PG", 72 },
		} },
		{ year = 2008, roster = {
			{ "Kevin Garnett", "PF", 94 }, { "Paul Pierce", "SF", 92 }, { "Ray Allen", "SG", 89 },
			{ "Rajon Rondo", "PG", 83 }, { "Kendrick Perkins", "C", 77 }, { "James Posey", "SF", 77 },
			{ "Eddie House", "PG", 74 }, { "Leon Powe", "PF", 73 },
		} },
		{ year = 2024, roster = {
			{ "Jayson Tatum", "SF/PF", 94 }, { "Jaylen Brown", "SG/SF", 90 }, { "Kristaps Porzingis", "C/PF", 87 },
			{ "Jrue Holiday", "PG/SG", 86 }, { "Derrick White", "PG/SG", 86 }, { "Al Horford", "C/PF", 81 },
			{ "Payton Pritchard", "PG", 76 }, { "Sam Hauser", "SF", 75 },
		} },
	} },
	{ id = "Warriors", city = "Golden State", name = "Warriors", color = { 29, 66, 138 }, eras = {
		{ year = 2016, roster = {
			{ "Stephen Curry", "PG", 98 }, { "Klay Thompson", "SG", 89 }, { "Draymond Green", "PF", 89 },
			{ "Andre Iguodala", "SF/SG", 82 }, { "Harrison Barnes", "SF", 80 }, { "Andrew Bogut", "C", 80 },
			{ "Shaun Livingston", "PG", 77 }, { "Festus Ezeli", "C", 73 },
		} },
		{ year = 2017, roster = {
			{ "Kevin Durant", "SF/PF", 97 }, { "Stephen Curry", "PG", 96 }, { "Klay Thompson", "SG", 90 },
			{ "Draymond Green", "PF", 90 }, { "Andre Iguodala", "SF", 81 }, { "JaVale McGee", "C", 77 },
			{ "Zaza Pachulia", "C", 76 }, { "David West", "PF", 75 },
		} },
		{ year = 2022, roster = {
			{ "Stephen Curry", "PG", 95 }, { "Draymond Green", "PF", 86 }, { "Andrew Wiggins", "SF", 84 },
			{ "Klay Thompson", "SG", 83 }, { "Jordan Poole", "SG/PG", 82 }, { "Kevon Looney", "C", 78 },
			{ "Otto Porter Jr.", "SF/PF", 77 }, { "Gary Payton II", "SG/PG", 77 },
		} },
	} },
	{ id = "Spurs", city = "San Antonio", name = "Spurs", color = { 138, 148, 153 }, eras = {
		{ year = 2003, roster = {
			{ "Tim Duncan", "PF/C", 97 }, { "David Robinson", "C", 85 }, { "Tony Parker", "PG", 84 },
			{ "Manu Ginobili", "SG", 82 }, { "Stephen Jackson", "SF/SG", 80 }, { "Bruce Bowen", "SF", 79 },
			{ "Malik Rose", "PF", 74 }, { "Speedy Claxton", "PG", 73 },
		} },
		{ year = 2014, roster = {
			{ "Tim Duncan", "PF/C", 88 }, { "Tony Parker", "PG", 88 }, { "Kawhi Leonard", "SF", 87 },
			{ "Manu Ginobili", "SG", 85 }, { "Danny Green", "SG", 80 }, { "Boris Diaw", "PF", 80 },
			{ "Tiago Splitter", "C", 79 }, { "Patty Mills", "PG", 77 },
		} },
	} },
	{ id = "Heat", city = "Miami", name = "Heat", color = { 152, 0, 46 }, eras = {
		{ year = 2006, roster = {
			{ "Dwyane Wade", "SG", 95 }, { "Shaquille O'Neal", "C", 90 }, { "Antoine Walker", "PF", 79 },
			{ "Alonzo Mourning", "C", 79 }, { "Udonis Haslem", "PF", 78 }, { "Jason Williams", "PG", 77 },
			{ "James Posey", "SF", 77 }, { "Gary Payton", "PG", 75 },
		} },
		{ year = 2013, roster = {
			{ "LeBron James", "SF/PF", 99 }, { "Dwyane Wade", "SG", 90 }, { "Chris Bosh", "PF/C", 88 },
			{ "Ray Allen", "SG", 81 }, { "Shane Battier", "SF/PF", 78 }, { "Mario Chalmers", "PG", 77 },
			{ "Chris Andersen", "C", 77 }, { "Udonis Haslem", "PF", 75 },
		} },
	} },
	{ id = "Cavaliers", city = "Cleveland", name = "Cavaliers", color = { 134, 0, 56 }, eras = {
		{ year = 2009, roster = {
			{ "LeBron James", "SF", 98 }, { "Mo Williams", "PG", 83 }, { "Zydrunas Ilgauskas", "C", 80 },
			{ "Delonte West", "SG/PG", 78 }, { "Anderson Varejao", "C/PF", 78 }, { "Ben Wallace", "C", 74 },
			{ "Wally Szczerbiak", "SF", 74 }, { "Daniel Gibson", "PG", 73 },
		} },
		{ year = 2016, roster = {
			{ "LeBron James", "SF/PF", 98 }, { "Kyrie Irving", "PG", 91 }, { "Kevin Love", "PF", 87 },
			{ "J.R. Smith", "SG", 79 }, { "Tristan Thompson", "C/PF", 79 }, { "Iman Shumpert", "SG", 75 },
			{ "Richard Jefferson", "SF", 75 }, { "Matthew Dellavedova", "PG", 74 },
		} },
	} },
	{ id = "Rockets", city = "Houston", name = "Rockets", color = { 206, 17, 65 }, eras = {
		{ year = 1994, roster = {
			{ "Hakeem Olajuwon", "C", 97 }, { "Otis Thorpe", "PF", 81 }, { "Vernon Maxwell", "SG", 79 },
			{ "Kenny Smith", "PG", 79 }, { "Robert Horry", "SF/PF", 79 }, { "Mario Elie", "SG/SF", 76 },
			{ "Sam Cassell", "PG", 75 },
		} },
		{ year = 2018, roster = {
			{ "James Harden", "SG/PG", 97 }, { "Chris Paul", "PG", 92 }, { "Clint Capela", "C", 84 },
			{ "Eric Gordon", "SG", 80 }, { "Trevor Ariza", "SF", 79 }, { "P.J. Tucker", "PF", 77 },
			{ "Gerald Green", "SG/SF", 74 }, { "Luc Mbah a Moute", "SF", 74 },
		} },
	} },
	{ id = "Pistons", city = "Detroit", name = "Pistons", color = { 200, 16, 46 }, eras = {
		{ year = 1989, roster = {
			{ "Isiah Thomas", "PG", 92 }, { "Joe Dumars", "SG", 86 }, { "Dennis Rodman", "PF/SF", 84 },
			{ "Bill Laimbeer", "C", 83 }, { "Mark Aguirre", "SF", 82 }, { "Vinnie Johnson", "SG", 80 },
			{ "Rick Mahorn", "PF", 78 }, { "James Edwards", "C", 76 },
		} },
		{ year = 2004, roster = {
			{ "Chauncey Billups", "PG", 89 }, { "Ben Wallace", "C", 88 }, { "Richard Hamilton", "SG", 85 },
			{ "Rasheed Wallace", "PF", 85 }, { "Tayshaun Prince", "SF", 82 }, { "Mehmet Okur", "C/PF", 77 },
			{ "Corliss Williamson", "PF", 74 }, { "Lindsey Hunter", "PG", 73 },
		} },
	} },
	{ id = "Knicks", city = "New York", name = "Knicks", color = { 245, 132, 38 }, eras = {
		{ year = 1994, roster = {
			{ "Patrick Ewing", "C", 92 }, { "John Starks", "SG", 82 }, { "Charles Oakley", "PF", 82 },
			{ "Derek Harper", "PG", 78 }, { "Anthony Mason", "PF/SF", 78 }, { "Charles Smith", "PF", 75 },
			{ "Hubert Davis", "SG", 74 }, { "Greg Anthony", "PG", 73 },
		} },
		{ year = 2024, roster = {
			{ "Jalen Brunson", "PG", 92 }, { "Julius Randle", "PF", 85 }, { "OG Anunoby", "SF/PF", 84 },
			{ "Josh Hart", "SG/SF", 82 }, { "Donte DiVincenzo", "SG", 81 }, { "Isaiah Hartenstein", "C", 81 },
			{ "Mitchell Robinson", "C", 79 }, { "Miles McBride", "PG", 75 },
		} },
	} },
	{ id = "Suns", city = "Phoenix", name = "Suns", color = { 29, 17, 96 }, eras = {
		{ year = 1993, roster = {
			{ "Charles Barkley", "PF", 96 }, { "Kevin Johnson", "PG", 88 }, { "Dan Majerle", "SG/SF", 83 },
			{ "Tom Chambers", "PF", 79 }, { "Danny Ainge", "SG", 77 }, { "Richard Dumas", "SF", 76 },
			{ "Cedric Ceballos", "SF", 76 }, { "Mark West", "C", 74 },
		} },
		{ year = 2005, roster = {
			{ "Steve Nash", "PG", 93 }, { "Amar'e Stoudemire", "PF/C", 91 }, { "Shawn Marion", "SF/PF", 89 },
			{ "Joe Johnson", "SG", 84 }, { "Quentin Richardson", "SF/SG", 79 }, { "Leandro Barbosa", "SG", 78 },
			{ "Jim Jackson", "SF", 74 }, { "Steven Hunter", "C", 72 },
		} },
		{ year = 2021, roster = {
			{ "Devin Booker", "SG", 91 }, { "Chris Paul", "PG", 91 }, { "Deandre Ayton", "C", 85 },
			{ "Mikal Bridges", "SF", 83 }, { "Jae Crowder", "PF", 79 }, { "Cameron Johnson", "PF/SF", 78 },
			{ "Cameron Payne", "PG", 76 }, { "Dario Saric", "PF", 74 },
		} },
	} },
	{ id = "Jazz", city = "Utah", name = "Jazz", color = { 249, 160, 27 }, eras = {
		{ year = 1997, roster = {
			{ "Karl Malone", "PF", 95 }, { "John Stockton", "PG", 91 }, { "Jeff Hornacek", "SG", 84 },
			{ "Bryon Russell", "SF", 78 }, { "Greg Ostertag", "C", 75 }, { "Antoine Carr", "PF", 75 },
			{ "Howard Eisley", "PG", 74 }, { "Shandon Anderson", "SG/SF", 73 },
		} },
		{ year = 2007, roster = {
			{ "Deron Williams", "PG", 88 }, { "Carlos Boozer", "PF", 86 }, { "Mehmet Okur", "C", 82 },
			{ "Andrei Kirilenko", "SF/PF", 82 }, { "Matt Harpring", "SF", 78 }, { "Derek Fisher", "PG", 77 },
			{ "Paul Millsap", "PF", 76 }, { "Gordan Giricek", "SG", 74 },
		} },
	} },
	{ id = "Thunder", city = "Oklahoma City", name = "Thunder", color = { 0, 125, 195 }, eras = {
		{ year = 2012, roster = {
			{ "Kevin Durant", "SF", 96 }, { "Russell Westbrook", "PG", 92 }, { "James Harden", "SG", 87 },
			{ "Serge Ibaka", "PF/C", 83 }, { "Kendrick Perkins", "C", 75 }, { "Thabo Sefolosha", "SG/SF", 75 },
			{ "Nick Collison", "PF", 75 }, { "Derek Fisher", "PG", 72 },
		} },
		{ year = 2025, roster = {
			{ "Shai Gilgeous-Alexander", "PG/SG", 97 }, { "Jalen Williams", "SF/SG", 88 }, { "Chet Holmgren", "C/PF", 86 },
			{ "Isaiah Hartenstein", "C", 81 }, { "Luguentz Dort", "SG", 80 }, { "Alex Caruso", "SG", 80 },
			{ "Cason Wallace", "PG/SG", 77 }, { "Aaron Wiggins", "SG", 75 },
		} },
	} },
	{ id = "Mavericks", city = "Dallas", name = "Mavericks", color = { 0, 83, 188 }, eras = {
		{ year = 2011, roster = {
			{ "Dirk Nowitzki", "PF", 95 }, { "Jason Kidd", "PG", 84 }, { "Tyson Chandler", "C", 84 },
			{ "Jason Terry", "SG", 83 }, { "Shawn Marion", "SF", 81 }, { "J.J. Barea", "PG", 76 },
			{ "Peja Stojakovic", "SF", 75 }, { "DeShawn Stevenson", "SG", 73 },
		} },
		{ year = 2024, roster = {
			{ "Luka Doncic", "PG", 97 }, { "Kyrie Irving", "PG/SG", 91 }, { "P.J. Washington", "PF", 80 },
			{ "Daniel Gafford", "C", 80 }, { "Dereck Lively II", "C", 80 }, { "Derrick Jones Jr.", "SF", 78 },
			{ "Josh Green", "SG", 74 }, { "Maxi Kleber", "PF", 74 },
		} },
	} },
	{ id = "Nuggets", city = "Denver", name = "Nuggets", color = { 13, 34, 64 }, eras = {
		{ year = 2009, roster = {
			{ "Carmelo Anthony", "SF", 90 }, { "Chauncey Billups", "PG", 87 }, { "Nene", "C/PF", 82 },
			{ "J.R. Smith", "SG", 80 }, { "Kenyon Martin", "PF", 79 }, { "Chris Andersen", "C", 77 },
			{ "Linas Kleiza", "SF", 74 }, { "Dahntay Jones", "SG", 73 },
		} },
		{ year = 2023, roster = {
			{ "Nikola Jokic", "C", 98 }, { "Jamal Murray", "PG", 89 }, { "Michael Porter Jr.", "SF/PF", 84 },
			{ "Aaron Gordon", "PF", 83 }, { "Kentavious Caldwell-Pope", "SG", 80 }, { "Bruce Brown", "SG/PG", 79 },
			{ "Christian Braun", "SG", 74 }, { "Jeff Green", "PF", 73 },
		} },
	} },
	{ id = "Bucks", city = "Milwaukee", name = "Bucks", color = { 0, 71, 27 }, eras = {
		{ year = 2001, roster = {
			{ "Ray Allen", "SG", 89 }, { "Sam Cassell", "PG", 86 }, { "Glenn Robinson", "SF", 85 },
			{ "Tim Thomas", "SF/PF", 78 }, { "Ervin Johnson", "C", 74 }, { "Lindsey Hunter", "PG", 73 },
			{ "Scott Williams", "PF", 72 }, { "Joel Przybilla", "C", 70 },
		} },
		{ year = 2021, roster = {
			{ "Giannis Antetokounmpo", "PF", 98 }, { "Khris Middleton", "SF", 87 }, { "Jrue Holiday", "PG", 86 },
			{ "Brook Lopez", "C", 81 }, { "Bobby Portis", "PF/C", 79 }, { "Donte DiVincenzo", "SG", 76 },
			{ "P.J. Tucker", "PF", 75 }, { "Pat Connaughton", "SG", 75 },
		} },
	} },
	{ id = "76ers", city = "Philadelphia", name = "76ers", color = { 0, 107, 182 }, eras = {
		{ year = 1983, roster = {
			{ "Moses Malone", "C", 95 }, { "Julius Erving", "SF", 92 }, { "Maurice Cheeks", "PG", 84 },
			{ "Andrew Toney", "SG", 84 }, { "Bobby Jones", "PF", 80 }, { "Marc Iavaroni", "PF", 72 },
			{ "Clint Richardson", "SG", 72 },
		} },
		{ year = 2001, roster = {
			{ "Allen Iverson", "SG/PG", 95 }, { "Dikembe Mutombo", "C", 87 }, { "Aaron McKie", "SG", 79 },
			{ "Eric Snow", "PG", 78 }, { "Tyrone Hill", "PF", 77 }, { "George Lynch", "SF", 74 },
			{ "Jumaine Jones", "SF", 71 }, { "Todd MacCulloch", "C", 71 },
		} },
	} },
	{ id = "Clippers", city = "LA", name = "Clippers", color = { 200, 16, 46 }, eras = {
		{ year = 2014, roster = {
			{ "Chris Paul", "PG", 95 }, { "Blake Griffin", "PF", 91 }, { "DeAndre Jordan", "C", 85 },
			{ "Jamal Crawford", "SG", 82 }, { "J.J. Redick", "SG", 81 }, { "Darren Collison", "PG", 78 },
			{ "Matt Barnes", "SF", 76 }, { "Jared Dudley", "SF", 73 },
		} },
		{ year = 2020, roster = {
			{ "Kawhi Leonard", "SF", 96 }, { "Paul George", "SF/SG", 90 }, { "Lou Williams", "SG", 82 },
			{ "Montrezl Harrell", "C/PF", 82 }, { "Ivica Zubac", "C", 79 }, { "Marcus Morris Sr.", "PF", 79 },
			{ "Patrick Beverley", "PG", 77 }, { "Reggie Jackson", "PG", 76 },
		} },
	} },
	{ id = "Raptors", city = "Toronto", name = "Raptors", color = { 206, 17, 65 }, eras = {
		{ year = 2001, roster = {
			{ "Vince Carter", "SG/SF", 94 }, { "Antonio Davis", "C/PF", 81 }, { "Alvin Williams", "PG", 77 },
			{ "Morris Peterson", "SF", 76 }, { "Charles Oakley", "PF", 76 }, { "Keon Clark", "C", 75 },
			{ "Chris Childs", "PG", 74 }, { "Jerome Williams", "PF", 74 },
		} },
		{ year = 2019, roster = {
			{ "Kawhi Leonard", "SF", 97 }, { "Kyle Lowry", "PG", 88 }, { "Pascal Siakam", "PF", 87 },
			{ "Marc Gasol", "C", 83 }, { "Serge Ibaka", "PF/C", 81 }, { "Fred VanVleet", "PG/SG", 80 },
			{ "Danny Green", "SG", 79 }, { "Norman Powell", "SG", 76 },
		} },
	} },
	{ id = "Magic", city = "Orlando", name = "Magic", color = { 0, 125, 197 }, eras = {
		{ year = 1995, roster = {
			{ "Shaquille O'Neal", "C", 95 }, { "Penny Hardaway", "PG/SG", 92 }, { "Horace Grant", "PF", 82 },
			{ "Nick Anderson", "SG/SF", 82 }, { "Dennis Scott", "SF", 79 }, { "Brian Shaw", "PG", 73 },
			{ "Donald Royal", "SF", 72 },
		} },
		{ year = 2009, roster = {
			{ "Dwight Howard", "C", 93 }, { "Rashard Lewis", "PF/SF", 83 }, { "Hedo Turkoglu", "SF", 82 },
			{ "Jameer Nelson", "PG", 82 }, { "Rafer Alston", "PG", 76 }, { "Courtney Lee", "SG", 76 },
			{ "Mickael Pietrus", "SF/SG", 75 }, { "Marcin Gortat", "C", 74 },
		} },
	} },
	{ id = "Timberwolves", city = "Minnesota", name = "Timberwolves", color = { 120, 190, 32 }, eras = {
		{ year = 2004, roster = {
			{ "Kevin Garnett", "PF", 97 }, { "Sam Cassell", "PG", 87 }, { "Latrell Sprewell", "SG/SF", 83 },
			{ "Wally Szczerbiak", "SF", 79 }, { "Fred Hoiberg", "SG", 75 }, { "Trenton Hassell", "SF", 75 },
			{ "Ervin Johnson", "C", 72 }, { "Mark Madsen", "PF", 70 },
		} },
		{ year = 2024, roster = {
			{ "Anthony Edwards", "SG", 92 }, { "Karl-Anthony Towns", "C/PF", 88 }, { "Rudy Gobert", "C", 87 },
			{ "Mike Conley", "PG", 81 }, { "Naz Reid", "C/PF", 81 }, { "Jaden McDaniels", "SF", 80 },
			{ "Nickeil Alexander-Walker", "SG", 76 }, { "Kyle Anderson", "PF/SF", 75 },
		} },
	} },
}

local NBAData = {}
NBAData.franchises = {} :: { Franchise }
NBAData.byFranchise = {} :: { [string]: Franchise }
NBAData.eras = {} :: { Era }
NBAData.byKey = {} :: { [string]: Era }

-- Dynasty teams roll less often, so a stacked roster feels like a real pull.
local function rollWeight(bestOvr: number): number
	if bestOvr >= 97 then
		return 3
	elseif bestOvr >= 94 then
		return 6
	end
	return 10
end

for _, f in RAW do
	local franchise: Franchise = { id = f.id, city = f.city, name = f.name, color = f.color, eras = {} }
	for _, e in f.eras do
		local key = f.id .. "_" .. e.year
		local label = string.format("%d-%02d %s %s", e.year - 1, e.year % 100, f.city, f.name)
		local shortLabel = string.format("'%02d %s", e.year % 100, f.name)
		local era: Era = {
			key = key,
			franchise = f.id,
			year = e.year,
			label = label,
			shortLabel = shortLabel,
			color = f.color,
			weight = 0,
			players = {},
		}
		local best = 0
		for _, row in e.roster do
			local positions = {}
			for pos in string.gmatch(row[2] :: string, "[^/]+") do
				table.insert(positions, pos)
			end
			local ovr = row[3] :: number
			table.insert(era.players, {
				name = row[1] :: string,
				positions = positions,
				posText = row[2] :: string,
				ovr = ovr,
				teamKey = key,
				teamLabel = label,
				shortLabel = shortLabel,
				franchise = f.id,
			})
			best = math.max(best, ovr)
		end
		era.weight = rollWeight(best)
		table.insert(franchise.eras, era)
		table.insert(NBAData.eras, era)
		NBAData.byKey[key] = era
	end
	table.insert(NBAData.franchises, franchise)
	NBAData.byFranchise[f.id] = franchise
end

return NBAData
