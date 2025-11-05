local utils = require('mp.utils')

local MOVIES = { 'movie', 'tvMovie' }
local SERIES = { 'tvSeries' }

local function clean_title(s)
	return s:gsub('^%w+%-', ''):gsub('%.', ' ')
end

local function sequential_truthy(list, callback)
	local function step(i)
		local fn = list[i]
		if fn then
			fn(function(result)
				if result then
					callback(result)
				else
					step(i + 1)
				end
			end)
		else
			callback(nil)
		end
	end
	step(1)
end

local function encode_uri_component(s)
	return s:gsub('%W', function(c)
		return ('%%%02X'):format(string.byte(c))
	end)
end

local function get_extensions()
	local path = os.getenv('HOME')
		.. '/.local/share/mpv/imdb-search-extensions.json'
	local f, err = io.open(path)
	if not f then
		mp.msg.error(('Cannot read IMDB search extensions: %s'):format(err))
		return ''
	end
	local s = assert(f:read('*a'))
	assert(f:close())
	return s
end

-- https://www.imdb.com/search/title/
local function imdb_search(title, title_types, year, duration, callback)
	local start_time = mp.get_time()

	mp.msg.info(
		('Fetch IMDB: title=%q year=%q duration=%q'):format(title, year, duration)
	)

	local variables = {
		first = 10,
		locale = 'en-US',
		releaseDateConstraint = {
			releaseDateRange = year and {
				start = ('%s-01-01'):format(year - 1),
				['end'] = ('%s-12-31'):format(year + 1),
			},
		},
		sortBy = 'POPULARITY',
		sortOrder = 'ASC',
		titleTextConstraint = { searchTerm = title },
		titleTypeConstraint = { anyTitleTypeIds = title_types },
	}

	local url = ('https://caching.graphql.imdb.com/?operationName=AdvancedTitleSearch&variables=%s&extensions=%s'):format(
		encode_uri_component(utils.format_json(variables)),
		encode_uri_component(get_extensions())
	)

	mp.command_native_async({
		name = 'subprocess',
		playback_only = false,
		capture_stdout = true,
		args = {
			'curl',
			'--silent',
			'--fail',
			'--compressed',
			'--globoff',
			'--max-time',
			'10',
			url,
			'-H',
			'accept: application/graphql+json, application/json',
			'-H',
			'content-type: application/json',
		},
	}, function(success, result, err)
		assert(success, err)

		if result.status ~= 0 then
			mp.msg.error(('Fetch IMDB failed: %s'):format(result.stdout))
			callback(nil)
			return
		end

		local response = utils.parse_json(result.stdout)

		if response.errors then
			mp.msg.error(utils.to_string(response.errors))
			callback(nil)
			return
		end

		local list = {}

		for i, edge in ipairs(response.data.advancedTitleSearch.edges) do
			local data = edge.node.title
			table.insert(list, {
				index = i,
				title = assert(data.titleText.text),
				year = data.releaseYear and assert(data.releaseYear.year),
				rating = data.ratingsSummary.aggregateRating or 0,
				duration = data.runtime and assert(data.runtime.seconds),
				image_url = data.primaryImage and assert(data.primaryImage.url),
			})
		end

		table.sort(list, function(a, b)
			if year then
				local ax = math.abs(a.year - year)
				local bx = math.abs(b.year - year)
				if ax ~= bx then
					return ax < bx
				end
			end

			if duration and a.duration and b.duration then
				local ax = math.abs(a.duration - duration)
				local bx = math.abs(b.duration - duration)
				if ax ~= bx then
					return ax < bx
				end
			end

			if #a.title ~= #b.title then
				return #a.title < #b.title
			end

			return a.index < b.index
		end)

		mp.msg.debug(
			('%d matches in %.3f s'):format(#list, mp.get_time() - start_time)
		)

		callback(list[1])
	end)
end

local function search_movie(query, duration, callback)
	local title, year = query:match('^(.-)(%d%d%d%d)')
	title = title or query:match('^(.-)%d%d') or query
	-- "'s" handled correctly for some reason.
	local title_alt = title:lower():gsub('&', ''):gsub('([^ ]+)', {
		['and'] = '',
		youre = "you're",
	})
	sequential_truthy({
		function(callback)
			imdb_search(title, MOVIES, year, duration, callback)
		end,
		function(callback)
			if title_alt == title then
				callback(nil)
				return
			end
			imdb_search(title_alt, MOVIES, year, duration, callback)
		end,
		function(callback)
			imdb_search(title, MOVIES, nil, duration, callback)
		end,
	}, callback)
end

local function search_series(query, callback)
	local title = query:match('^(.-)[sS]%d+[eE]%d+')
	if not title then
		callback(nil)
		return
	end
	sequential_truthy({
		function(callback)
			imdb_search(title, SERIES, nil, nil, callback)
		end,
	}, callback)
end

local function search_title(query, duration, callback)
	mp.msg.info(('Search IMDB: %q'):format(query))
	query = clean_title(query)
	sequential_truthy({
		function(callback)
			search_series(query, callback)
		end,
		function(callback)
			search_movie(query, duration, callback)
		end,
	}, callback)
end

-- MPV_SCRIPT_IMDB_TEST= mpv --idle --msg-level=lua=debug
if os.getenv('MPV_SCRIPT_IMDB_TEST') then
	local tests = {}

	local function test(input, duration, expected_title, expected_year)
		table.insert(tests, function(callback)
			search_title(input, duration, function(result)
				assert(result ~= nil, 'No matches found')
				assert(
					result.title == expected_title,
					('Expected %q, got %q'):format(expected_title, result.title)
				)
				assert(
					result.year == expected_year,
					('Expected %q, got %q'):format(expected_year, result.year)
				)
				assert(result.rating > 0, 'Expected rating to be valid')
				print('OK.')
				callback()
			end)
		end)
	end

	test('Oddity.2024', 5920, 'Oddity', 2024)
	test('The.River.2018', 5710, 'The River', 2018)
	test('Youre.Cordially.Invited.2025', 6683, "You're Cordially Invited", 2025)
	test('Es.mi.van.Tomival.2024', 5778, 'But What About Tomi?', 2024)
	test('Luccas.World.2024', 5794, "Lucca's World", 2025)
	test('The.Childrens.Train.2024', 6384, "The Children's Train", 2024)
	test('Swing.Into.Romance.2023', 5108, 'Swing Into Romance', 2023)
	test('Gladiator.II.2024', 9102, 'Gladiator II', 2024)
	test('Troppa.grazia.2018', 6572, "Lucia's Grace", 2018)
	test('Juror.2.2024', 6829, 'Juror #2', 2024)
	test('Juror.2.720.720', 6829, 'Juror #2', 2024)
	test('Burning.Lies.2021', 5355, 'Burning Little Lies', 2021)
	test('Budapesti.zsaruk.S01E01.1080i', 0, 'Budapesti Zsaruk', 2025)
	test('Unmoored.2024', 5378, 'Unmoored', 2023)
	test('Most.Likely.to.Murder.2019', 5396, 'Most Likely to Murder', 2019)
	test('aX059-crazy.stupid.love.720', 7087, 'Crazy, Stupid, Love.', 2011)
	test(
		'Wallace.and.Gromit.Vengeance.Most.Fowl.2025',
		4946,
		'Wallace & Gromit: Vengeance Most Fowl',
		2024
	)
	test(
		'squid.game.the.challenge.s02e0.xxx',
		0,
		'Squid Game: The Challenge',
		2023
	)

	sequential_truthy(tests, function()
		print('All OK.')
	end)
end

return { search_title = search_title }
