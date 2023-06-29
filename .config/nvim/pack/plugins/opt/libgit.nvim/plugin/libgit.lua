local gits = {}

function update_status(repo)
	local s = ''

	if repo.is_detached then
		s = s .. 'detached '
	end

	if repo.is_unborn then
		s = s .. 'unborn '
	end

	s = s .. repo.head

	if repo.is_dirty then
		s = s .. '*'
	end

	if repo.has_stash then
		s = s .. '$'
	end

	if repo.behind == 0 and repo.ahead == 0 then
		s = s .. '='
	end

	if repo.behind and repo.behind > 0 then
		s = s .. '<'
		if repo.behind > 1 then
			s = s .. repo.behind
		end
	end
	if repo.ahead and repo.ahead > 0 then
		s = s .. '>'
		if repo.ahead > 1 then
			s = s .. repo.ahead
		end
	end

	return s
	-- lua vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace('test'), 20, 1, {number_hl_group = 'Search'})
	-- git_diff_foreach

	-- print(libgit2.git_repository_state(self.repo))
end

local Worker = require('libgit.worker')
local worker = Worker:new(function(reply)
	--[[
		https://github.com/libgit2/libgit2.github.io/blob/main/docs/guides/101-samples/index.md
		]]
	local ffi = require('ffi')
	local uv = vim.loop

	-- cmake .. -G Ninja -DUSE_HTTP=OFF -DUSE_NTLMCLIENT=OFF
	local libgit2 = ffi.load(os.getenv('HOME') .. '/.local/lib/libgit2.so')

	ffi.cdef([[
typedef struct git_repository git_repository;
typedef struct git_reference git_reference;
typedef struct git_status_list git_status_list;
typedef struct git_object git_object;
typedef struct git_tree git_tree;
typedef struct git_revwalk git_revwalk;
typedef struct git_describe_result git_describe_result;

enum { GIT_OID_SHA1_SIZE = 20 };
enum { GIT_OID_MAX_SIZE = GIT_OID_SHA1_SIZE };
typedef struct git_oid {
	unsigned char id[GIT_OID_MAX_SIZE];
} git_oid;

enum {
	GIT_REPOSITORY_OPEN_FROM_ENV = (1 << 4),
};

typedef struct {
	char *message;
	int klass;
} git_error;

typedef struct git_strarray {
	char **strings;
	size_t count;
} git_strarray;

typedef enum {
	GIT_STATUS_SHOW_INDEX_AND_WORKDIR = 0,
	GIT_STATUS_SHOW_INDEX_ONLY = 1,
	GIT_STATUS_SHOW_WORKDIR_ONLY = 2
} git_status_show_t;

enum { GIT_STATUS_OPTIONS_VERSION = 1 };
typedef struct {
	unsigned int version;
	git_status_show_t show;
	unsigned int flags;
	git_strarray pathspec;
	git_tree *baseline;
	uint16_t rename_threshold;
} git_status_options;

enum { GIT_DESCRIBE_OPTIONS_VERSION = 1 };
typedef struct {
	unsigned int version;
	unsigned int max_candidates_tags;
	unsigned int describe_strategy;
	const char *pattern;
	int only_follow_first_parent;
	int show_commit_oid_as_fallback;
} git_describe_options;

enum { GIT_DESCRIBE_FORMAT_OPTIONS_VERSION = 1 };
typedef struct {
	unsigned int version;
	unsigned int abbreviated_size;
	int always_use_long_format;
	const char *dirty_suffix;
} git_describe_format_options;

typedef struct {
	char *ptr;
	size_t reserved;
	size_t size;
} git_buf;

int git_libgit2_init(void);
int git_libgit2_shutdown(void);
const git_error *git_error_last(void);
int git_libgit2_version(int *major, int *minor, int *rev);

int git_repository_open_ext(git_repository **out, const char *path, unsigned int flags, const char *ceiling_dirs);
int git_repository_head(git_reference **out, git_repository *repo);
void git_repository_free(git_repository *repo);
const char *git_repository_path(const git_repository *repo);
int git_repository_head_detached(git_repository *repo);
int git_repository_head_unborn(git_repository *repo);

void git_reference_free(git_reference *ref);
const char *git_reference_name(const git_reference *ref);
const char *git_reference_shorthand(const git_reference *ref);
int git_reference_lookup(git_reference **out, git_repository *repo, const char *name);
int git_reference_dwim(git_reference **out, git_repository *repo, const char *shorthand);

const char *git_reference_symbolic_target(const git_reference *ref);

int git_status_list_new(git_status_list **out, git_repository *repo, const git_status_options *opts);
size_t git_status_list_entrycount(git_status_list *statuslist);
void git_status_list_free(git_status_list *statuslist);
int git_status_options_init(git_status_options *opts, unsigned int version);

int git_revparse_single(git_object **out, git_repository *repo, const char *spec);

int git_revwalk_new(git_revwalk **out, git_repository *repo);
int git_revwalk_push_range(git_revwalk *walk, const char *range);
void git_revwalk_free(git_revwalk *walk);
int git_revwalk_next(git_oid *out, git_revwalk *walk);

typedef int git_stash_cb(size_t index, const char *message, const git_oid *stash_id, void *payload);
int git_stash_foreach(git_repository *repo, git_stash_cb callback, void *payload);

void git_object_free(git_object *object);

int git_describe_options_init(git_describe_options *opts, unsigned int version);
int git_describe_commit(git_describe_result **result, git_object *committish, git_describe_options *opts);
void git_describe_result_free(git_describe_result *result);
int git_describe_format(git_buf *out, const git_describe_result *result, const git_describe_format_options *opts);
int git_describe_format_options_init(git_describe_format_options *opts, unsigned int version);

void git_buf_dispose(git_buf *buffer);
int git_reference_lookup(git_reference **out, git_repository *repo, const char *name);
		]])

	local function check_error(result)
		if result < 0 then
			error(ffi.string(libgit2.git_error_last().message))
		end
		return result
	end

	local function revparse_single(repo, spec)
		local out_object = ffi.new('git_object *[1]')
		check_error(libgit2.git_revparse_single(out_object, repo, spec))
		local object =
			ffi.gc(ffi.new('git_object *', out_object[0]), libgit2.git_object_free)
		return object
	end

	local function describe(repo, spec)
		local describe_opts = ffi.new('git_describe_options')
		check_error(
			libgit2.git_describe_options_init(
				describe_opts,
				libgit2.GIT_DESCRIBE_OPTIONS_VERSION
			)
		)

		local object = revparse_single(repo, spec)

		local out_describe_result = ffi.new('git_describe_result *[1]')
		check_error(
			libgit2.git_describe_commit(out_describe_result, object, describe_opts)
		)
		local describe_result = ffi.gc(
			ffi.new('git_describe_result *', out_describe_result[0]),
			libgit2.git_describe_result_free
		)

		local format_opts = ffi.new('git_describe_format_options')
		check_error(
			libgit2.git_describe_format_options_init(
				format_opts,
				libgit2.GIT_DESCRIBE_FORMAT_OPTIONS_VERSION
			)
		)

		local buffer = ffi.gc(ffi.new('git_buf'), libgit2.git_buf_dispose)
		check_error(
			libgit2.git_describe_format(buffer, describe_result, format_opts)
		)
		local s = ffi.string(buffer.ptr, buffer.size)
		-- (buffer)

		return s
	end

	local function get_head(repo)
		-- print(describe(repo, 'HEAD'))
		local out_ref = ffi.new('git_reference *[1]')

		check_error(libgit2.git_repository_head(out_ref, repo))

		-- check_error(libgit2.git_reference_dwim(out_ref, repo, '@'));

		--[[ check_error(libgit2.git_reference_lookup(
				out_ref,
				repo,
				'HEAD'
			)); ]]

		local ref =
			ffi.gc(ffi.new('git_reference *', out_ref[0]), libgit2.git_reference_free)

		--[[ print(ffi.string(libgit2.git_reference_symbolic_target(ref)))
			print(ffi.string(libgit2.git_reference_name(ref))) ]]

		return ffi.string(libgit2.git_reference_shorthand(ref))
	end

	local function has_stash(repo)
		local any = false
		check_error(libgit2.git_stash_foreach(repo, function()
			any = true
			return 1 -- Stop iteration.
		end, nil))
		return any
	end

	local function is_detached(repo)
		return check_error(libgit2.git_repository_head_detached(repo)) == 1
	end

	local function is_unborn(repo)
		return check_error(libgit2.git_repository_head_unborn(repo)) == 1
	end

	local function is_dirty(repo)
		local status_opts = ffi.new('git_status_options')

		check_error(
			libgit2.git_status_options_init(
				status_opts,
				libgit2.GIT_STATUS_OPTIONS_VERSION
			)
		)

		local out_status = ffi.new('git_status_list *[1]')
		check_error(libgit2.git_status_list_new(out_status, repo, status_opts))
		local status = ffi.gc(
			ffi.new('git_status_list *', out_status[0]),
			libgit2.git_status_list_free
		)

		return libgit2.git_status_list_entrycount(status) > 0
	end

	local function get_path(repo)
		return ffi.string(libgit2.git_repository_path(repo))
	end

	local function count_range(repo, spec)
		local out_walker = ffi.new('git_revwalk *[1]')
		check_error(libgit2.git_revwalk_new(out_walker, repo))
		local walker = ffi.gc(out_walker[0], libgit2.git_revwalk_free)
		check_error(libgit2.git_revwalk_push_range(walker, spec))

		local oid = ffi.new('git_oid[1]')
		local count = 0
		while libgit2.git_revwalk_next(oid, walker) == 0 do
			count = count + 1
			-- , ffi.string(oid[0].id, libgit2.GIT_OID_MAX_SIZE)
		end
		return count
	end

	local function get_behind(repo)
		local ok, count = pcall(count_range, repo, '@..@{upstream}')
		return ok and count or -1
	end

	local function get_ahead(repo)
		local ok, count = pcall(count_range, repo, '@{upstream}..@')
		return ok and count or -1
	end

	local function update(repo)
		local path = get_path(repo)
		reply({
			type = 'update',
			repo = {
				path = path,
				head = get_head(repo),
				is_detached = is_detached(repo),
				is_unborn = is_unborn(repo),
			},
		})
		reply({
			type = 'update',
			repo = {
				path = path,
				ahead = get_ahead(repo),
				behind = get_behind(repo),
			},
		})
		reply({
			type = 'update',
			repo = {
				path = path,
				is_dirty = false and is_dirty(repo),
			},
		})
		reply({
			type = 'update',
			repo = {
				path = path,
				has_stash = has_stash(repo),
			},
		})
	end

	assert(check_error(libgit2.git_libgit2_init()) > 0)

	local iii = 0

	local repos = {}
	local watchers = {}
	local active_watchers = {}

	local a = os.clock()
	return function(message)
		if message == nil then
			-- WTF: If not called, SIGSEGVs.
			assert(check_error(libgit2.git_libgit2_shutdown()) == 0)
			return
		end

		-- print('request', vim.inspect(message))

		if message.type == 'version' then
			local major = ffi.new('int[1]')
			local minor = ffi.new('int[1]')
			local rev = ffi.new('int[1]')
			assert(libgit2.git_libgit2_version(major, minor, rev) == 0)
			message.payload = string.format(
				'libgit2 version %d.%d.%d',
				tonumber(major[0]),
				tonumber(minor[0]),
				tonumber(rev[0])
			)
		elseif message.type == 'open' then
			local path = assert(message.payload)

			assert(not repos[path])
			local out_repo = ffi.new('git_repository *[1]')
			check_error(
				libgit2.git_repository_open_ext(
					out_repo,
					path,
					libgit2.GIT_REPOSITORY_OPEN_FROM_ENV,
					nil
				)
			)
			local repo = ffi.gc(
				ffi.new('git_repository *', out_repo[0]),
				libgit2.git_repository_free
			)

			local repo_path = get_path(repo)

			local watcher = uv.new_fs_event()
			uv.fs_event_start(watcher, repo_path, {}, function(err)
				assert(not err)
				if active_watchers[repo_path] then
					return
				end

				local timer = uv.new_timer()
				timer:start(10, 0, function()
					timer:stop()
					timer:close()
					active_watchers[repo_path] = nil
					update(repo)
				end)

				active_watchers[repo_path] = timer
			end)
			watchers[repo] = watcher

			repos[repo_path] = repo
			if path ~= repo_path then
				repos[path] = repo
				reply({
					type = 'map',
					inside_path = path,
					repo_path = repo_path,
				})
			end

			return update(repo)
		elseif message.type == 'update' then
			local path = assert(message.payload)
			local repo = assert(repos[path])

			return update(repo)
		elseif message.type == 'close' then
			local path = message.payload

			local repo = repos[path]
			repos[path] = nil

			local last = true
			for _, r in pairs(repos) do
				if r == repo then
					last = false
					break
				end
			end

			if last then
				uv.fs_event_stop(watchers[repo])
			end
		end
		return reply(message)
	end
end, function(reply)
	-- print('reply', vim.inspect(reply))
	if reply.type == 'version' then
		print(reply.payload)
	elseif reply.type == 'map' then
		gits[reply.repo_path] = gits[reply.repo_path] or {
			status = '',
		}
		gits[reply.inside_path] = gits[reply.repo_path]
	elseif reply.type == 'update' then
		local t = gits[reply.repo.path]
		for k, v in pairs(reply.repo) do
			t[k] = reply.repo[k]
		end
		t.status = update_status(t)
		vim.schedule(vim.cmd.redrawstatus)
	end
end)

function _G.GitStatus()
	return _G.GitBuffer().status
end

function _G.GitBuffer()
	local path = vim.fn.expand('%:h')
	if path == '' then
		path = '.'
	end
	path = vim.fn.fnamemodify(path, ':p')
	return _G.Git(path)
end

function _G.Git(path)
	local Git = M

	if gits[path] then
		return gits[path]
	end

	local git = {
		status = '',
	}
	gits[path] = git
	worker:send_request({
		type = 'open',
		payload = path,
	})
	return git
end

vim.api.nvim_create_user_command('Gversion', function()
	worker:send_request({
		type = 'version',
	})
end, {})
