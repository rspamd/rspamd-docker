-- luacheck: globals rspamd_version
--
-- Build identity check for the rspamd Docker images.
--
-- Run it as a file (NOT with `rspamadm lua -e`, which exits 0 on errors):
--
--   IDENTITY_EXPECTED_DESCRIBE=4.0.1-0-g0123456789ab IDENTITY_RELEASE=true \
--     rspamadm lua /identity_check.lua
--
-- Environment:
--   IDENTITY_EXPECTED_DESCRIBE  expected `git describe --long` string (required)
--   IDENTITY_RELEASE            "true" for release builds, anything else = nightly
--
-- Exit status is 0 only if the final line printed is `identity-ok`; the caller
-- should also grep for that marker. Older rspamd without the identity selectors
-- prints `identity-skip` followed by `identity-ok` and succeeds.

local function parse_describe(s)
  local tag, dist, hash = tostring(s):match('^(.-)%-(%d+)%-g(%x+)$')
  if not tag then
    error(string.format("cannot parse describe string '%s'", tostring(s)))
  end
  return tag, tonumber(dist), hash
end

local function check()
  if rspamd_version('dev') == nil then
    print('identity-skip: rspamd_version() has no identity selectors')
    return
  end

  local expected = os.getenv('IDENTITY_EXPECTED_DESCRIBE')
  if not expected or expected == '' then
    error('IDENTITY_EXPECTED_DESCRIBE is not set')
  end
  local release = os.getenv('IDENTITY_RELEASE') == 'true'

  local describe = rspamd_version('describe')
  local dev = rspamd_version('dev')
  local distance = rspamd_version('distance')
  local base = rspamd_version('release_base')
  print(string.format('describe=%s release_base=%s distance=%s dev=%s',
      tostring(describe), tostring(base), tostring(distance), tostring(dev)))

  if type(describe) ~= 'string' or describe == '' then
    error('rspamd_version("describe") is empty: GIT_DESCRIBE was not baked in')
  end

  -- Compare tag, distance and hash prefix; the abbreviation length may differ
  local etag, edist, ehash = parse_describe(expected)
  local atag, adist, ahash = parse_describe(describe)
  if etag ~= atag then
    error(string.format('tag mismatch: expected %s, got %s', etag, atag))
  end
  if edist ~= adist then
    error(string.format('distance mismatch: expected %d, got %d', edist, adist))
  end
  local n = math.min(#ehash, #ahash)
  if n < 7 or ehash:sub(1, n) ~= ahash:sub(1, n) then
    error(string.format('commit mismatch: expected g%s, got g%s', ehash, ahash))
  end

  if distance ~= adist then
    error(string.format('rspamd_version("distance")=%s disagrees with describe (%d)',
        tostring(distance), adist))
  end
  if release then
    if dev ~= false then
      error('release build reports dev=' .. tostring(dev))
    end
    if adist ~= 0 then
      error('release build is not exactly on its tag, distance=' .. tostring(adist))
    end
  else
    -- Nightly: a development build, unless master sits exactly on a tag
    if dev ~= true and not (dev == false and adist == 0) then
      error(string.format('nightly build reports dev=%s with distance %d',
          tostring(dev), adist))
    end
  end
end

local ok, err = pcall(check)
if not ok then
  print('identity-fail: ' .. tostring(err))
  os.exit(1)
end
print('identity-ok')
