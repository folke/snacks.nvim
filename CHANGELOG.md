# Changelog

## [2.15.0](https://github.com/folke/snacks.nvim/compare/v2.14.0...v2.15.0) (2025-01-23)


### Features

* **debug:** truncate inspect to 2000 lines max ([570d219](https://github.com/folke/snacks.nvim/commit/570d2191d598d344ddd5b2a85d8e79d207955cc3))
* **input:** input history. Closes [#591](https://github.com/folke/snacks.nvim/issues/591) ([80db91f](https://github.com/folke/snacks.nvim/commit/80db91f03e3493e9b3aa09d1cd90b063ae0ec31c))
* **input:** persistent history. Closes [#591](https://github.com/folke/snacks.nvim/issues/591) ([0ed68bd](https://github.com/folke/snacks.nvim/commit/0ed68bdf7268bf1baef7a403ecc799f2c016b656))
* **picker.debug:** more info about potential leaks ([8d9677f](https://github.com/folke/snacks.nvim/commit/8d9677fc479710ae1f531fc52b0ac368def55b0b))
* **picker.filter:** Filter arg for filter ([5a4b684](https://github.com/folke/snacks.nvim/commit/5a4b684c0dd3eda10ce86f9710e085431a7656f2))
* **picker.finder:** optional transform function ([5e69fb8](https://github.com/folke/snacks.nvim/commit/5e69fb83d50bb79ff62352418733d11562e488d0))
* **picker.format:** `filename_only` option ([0396bdf](https://github.com/folke/snacks.nvim/commit/0396bdfc3eece8438ed6a978f1dbddf3f675ca36))
* **picker.git:** git_log, git_log_file, git_log_line now do git_checkout as confirm. Closes [#722](https://github.com/folke/snacks.nvim/issues/722) ([e6fb538](https://github.com/folke/snacks.nvim/commit/e6fb5381a9bfcbd0f1693ea9c7e3711045380187))
* **picker.help:** add more color to help tags ([5778234](https://github.com/folke/snacks.nvim/commit/5778234e3917999a0be1a5b8145dd83ab41035b3))
* **picker.keymaps:** add global + buffer toggles ([#705](https://github.com/folke/snacks.nvim/issues/705)) ([b7c08df](https://github.com/folke/snacks.nvim/commit/b7c08df2b8ff23e0293cfe06beaf60aa6fd14efc))
* **picker.keymaps:** improvements to keymaps picker ([2762c37](https://github.com/folke/snacks.nvim/commit/2762c37eb09bc434eba647d4ec079d6064d3c563))
* **picker.matcher:** frecency and cwd bonus can now be enabled on any picker ([7b85dfc](https://github.com/folke/snacks.nvim/commit/7b85dfc6f60538b0419ca1b969553891b64cd9b8))
* **picker.multi:** multi now also merges keymaps ([8b2c78a](https://github.com/folke/snacks.nvim/commit/8b2c78a3bf5a3ca52c8c9e46b9d15c288c59c5c1))
* **picker.preview:** better positioning of preview location ([3864955](https://github.com/folke/snacks.nvim/commit/38649556ee9f831e5d456043a796ae0fb115f8eb))
* **picker.preview:** fallback highlight of results when no `end_pos`. Mostly useful for grep. ([d12e454](https://github.com/folke/snacks.nvim/commit/d12e45433960210a16a37adc116e645e253578c1))
* **picker.smart:** add bufdelete actions from buffers picker ([#679](https://github.com/folke/snacks.nvim/issues/679)) ([67fbab1](https://github.com/folke/snacks.nvim/commit/67fbab1bf7f5c436e28af715097eecb2232eea59))
* **picker.smart:** re-implemented smart as multi-source picker ([450d1d4](https://github.com/folke/snacks.nvim/commit/450d1d4d4c218ac1df63924d29717caa61c98f27))
* **picker.util:** smart path truncate. Defaults to 40. Closes [#708](https://github.com/folke/snacks.nvim/issues/708) ([bab8243](https://github.com/folke/snacks.nvim/commit/bab8243395de8d8748a7295906bee7723b7b8190))
* **picker:** added `lazy` source to search for a plugin spec. Closes [#680](https://github.com/folke/snacks.nvim/issues/680) ([d03bd00](https://github.com/folke/snacks.nvim/commit/d03bd00ced5a03f1cb317b9227a6a1812e35a6c2))
* **picker:** added `opts.rtp` (bool) to find/grep over files in the rtp. See [#680](https://github.com/folke/snacks.nvim/issues/680) ([9d5d3bd](https://github.com/folke/snacks.nvim/commit/9d5d3bdb1747669d74587662cce93021fc99f878))
* **picker:** added new `icons` picker for nerd fonts and emoji. Closes [#703](https://github.com/folke/snacks.nvim/issues/703) ([97898e9](https://github.com/folke/snacks.nvim/commit/97898e910d92e50e886ba044ab255360e4271ffc))
* **picker:** getters and setters for cwd ([2c2ff4c](https://github.com/folke/snacks.nvim/commit/2c2ff4caf85ba1cfee3d946ea6ab9fd595ec3667))
* **picker:** multi source picker. Combine multiple pickers (as opposed to just finders) in one picker ([9434986](https://github.com/folke/snacks.nvim/commit/9434986ff15acfca7e010f159460f9ecfee81363))
* **picker:** persistent history. Closes [#528](https://github.com/folke/snacks.nvim/issues/528) ([ea665eb](https://github.com/folke/snacks.nvim/commit/ea665ebad18a8ccd6444df7476237de4164af64a))
* **picker:** preview window horizontal scrolling ([#686](https://github.com/folke/snacks.nvim/issues/686)) ([bc47e0b](https://github.com/folke/snacks.nvim/commit/bc47e0b1dd0102b58a90aba87f22e0cc0a48985c))
* **picker:** syntax highlighting for command and search history ([efb6d1f](https://github.com/folke/snacks.nvim/commit/efb6d1f8b8057e5f8455452c47ab769358902a18))
* **profiler:** added support for `Snacks.profiler` and dropped support for fzf-lua / telescope. Closes [#695](https://github.com/folke/snacks.nvim/issues/695) ([ada83de](https://github.com/folke/snacks.nvim/commit/ada83de9528d0825928726a6d252fb97271fb73a))


### Bug Fixes

* **picker.actions:** `checktime` after `git_checkout` ([b86d90e](https://github.com/folke/snacks.nvim/commit/b86d90e3e9c68f4d24a0208e873d35b0074c12b0))
* **picker.async:** better handling of abort and schedule/defer util function ([dfcf27e](https://github.com/folke/snacks.nvim/commit/dfcf27e2a90d4b262d2bd0e54c1b576dba296c73))
* **picker.async:** fixed aborting a coroutine from the coroutine itself. See [#665](https://github.com/folke/snacks.nvim/issues/665) ([c1e2c61](https://github.com/folke/snacks.nvim/commit/c1e2c619b229a3f2ccdc000a6fadddc7ca9f482d))
* **picker.files:** include symlinks ([dc9c6fb](https://github.com/folke/snacks.nvim/commit/dc9c6fbd028e0488a9292e030c788b72b16cbeca))
* **picker.frecency:** track visit on BufWinEnter instead of BufReadPost and exclude floating windows ([024a448](https://github.com/folke/snacks.nvim/commit/024a448e52563aadf9e5b234ddfb17168aa5ada7))
* **picker.git_branches:** handle detached HEAD ([#671](https://github.com/folke/snacks.nvim/issues/671)) ([390f687](https://github.com/folke/snacks.nvim/commit/390f6874318addcf48b668f900ef62d316c44602))
* **picker.git:** `--follow` only works for `git_log_file`. Closes [#666](https://github.com/folke/snacks.nvim/issues/666) ([23a8668](https://github.com/folke/snacks.nvim/commit/23a8668ef0b0c9d910c7bbcd57651d8889b0fa65))
* **picker.git:** parse all detached states. See [#671](https://github.com/folke/snacks.nvim/issues/671) ([2cac667](https://github.com/folke/snacks.nvim/commit/2cac6678a95f89a7e23ed668c9634eff9e60dbe5))
* **picker.grep:** off-by-one for grep results col ([e3455ef](https://github.com/folke/snacks.nvim/commit/e3455ef4dc96fac3b53f76e12c487007a5fca9e7))
* **picker.icons:** bump build for nerd fonts ([ba108e2](https://github.com/folke/snacks.nvim/commit/ba108e2aa86909168905e522342859ec9ed4e220))
* **picker.icons:** fix typo in Nerd Fonts and display the full category name ([#716](https://github.com/folke/snacks.nvim/issues/716)) ([a4b0a85](https://github.com/folke/snacks.nvim/commit/a4b0a85e3bc68fe1aeca1ee4161053dabaeb856c))
* **picker.icons:** opts.icons -&gt; opts.icon_sources. Fixes [#715](https://github.com/folke/snacks.nvim/issues/715) ([9e7bfc0](https://github.com/folke/snacks.nvim/commit/9e7bfc05d5e4a0f079f695cdd6869c219c762224))
* **picker.input:** better handling of `stopinsert` with prompt buffers. Closes [#723](https://github.com/folke/snacks.nvim/issues/723) ([c2916cb](https://github.com/folke/snacks.nvim/commit/c2916cb526d42fb6726cf9f7252ceb44516fc2f6))
* **picker.input:** correct cursor position in input when cycling / focus. Fixes [#688](https://github.com/folke/snacks.nvim/issues/688) ([93cca7a](https://github.com/folke/snacks.nvim/commit/93cca7a4b3923c291726305b301a51316b275bf2))
* **picker.lsp:** include_current on Windows. Closes [#678](https://github.com/folke/snacks.nvim/issues/678) ([66d2854](https://github.com/folke/snacks.nvim/commit/66d2854ea0c83339042b6340b29dfdc48982e75a))
* **picker.lsp:** make `lsp_symbols` work for unloaded buffers ([9db49b7](https://github.com/folke/snacks.nvim/commit/9db49b7e6c5ded7edeff8bec6327322fb6125695))
* **picker.lsp:** schedule_wrap cancel functions and resume when no clients ([6cbca8a](https://github.com/folke/snacks.nvim/commit/6cbca8adffd4014e9f67ba327f9c164f0412b685))
* **picker.lsp:** use async from ctx ([b878caa](https://github.com/folke/snacks.nvim/commit/b878caaddc7b91386ec95b3b2f034b275dc7f49a))
* **picker.lsp:** use correct buf/win ([8006caa](https://github.com/folke/snacks.nvim/commit/8006caadb3eedf2553a587497c508c01aadf098b))
* **picker.preview:** clear buftype for file previews ([5429dff](https://github.com/folke/snacks.nvim/commit/5429dff1cd51ceaa10134dbff4faf447823de017))
* **picker.undo:** use new API. Closes [#707](https://github.com/folke/snacks.nvim/issues/707) ([79a6eab](https://github.com/folke/snacks.nvim/commit/79a6eabd318d2b65d5786c4e3c2419eaa91c6240))
* **picker.util:** for `--` args require a space before ([ee6f21b](https://github.com/folke/snacks.nvim/commit/ee6f21bbd636e82691a0386f39f0c8310f8cadd8))
* **picker.util:** more relaxed resolve_loc ([964beb1](https://github.com/folke/snacks.nvim/commit/964beb11489afc2a2a1004bbb1b2b3286da9a8ac))
* **picker.util:** prevent empty shortened paths if it's the cwd. Fixes [#721](https://github.com/folke/snacks.nvim/issues/721) ([14f16ce](https://github.com/folke/snacks.nvim/commit/14f16ceb5d4dc53ddbd9b56992335658105d1d5f))
* **picker:** better handling of buffers with custom URIs. Fixes [#677](https://github.com/folke/snacks.nvim/issues/677) ([cd5eddb](https://github.com/folke/snacks.nvim/commit/cd5eddb1dea0ab69a451702395104cf716678b36))
* **picker:** don't jump to invalid positions. Fixes [#712](https://github.com/folke/snacks.nvim/issues/712) ([51adb67](https://github.com/folke/snacks.nvim/commit/51adb6792e1819c9cf0153606f506403f97647fe))
* **picker:** don't try showing the preview when the picker is closed. Fixes [#714](https://github.com/folke/snacks.nvim/issues/714) ([11c0761](https://github.com/folke/snacks.nvim/commit/11c07610557f0a6c6eb40bca60c60982ff6e3b93))
* **picker:** resume. Closes [#709](https://github.com/folke/snacks.nvim/issues/709) ([9b55a90](https://github.com/folke/snacks.nvim/commit/9b55a907bd0468752c3e5d9cd7e607cab206a6d7))
* **picker:** starting a picker from the picker sometimes didnt start in insert mode. Fixes [#718](https://github.com/folke/snacks.nvim/issues/718) ([08d4f14](https://github.com/folke/snacks.nvim/commit/08d4f14cd85466fd37d63b7123437c7d15bc87f6))
* **picker:** update title on find. Fixes [#717](https://github.com/folke/snacks.nvim/issues/717) ([431a24e](https://github.com/folke/snacks.nvim/commit/431a24e24e2a7066e44272f83410d7b44f497e26))
* **scroll:** handle buffer changes while animating ([3da0b0e](https://github.com/folke/snacks.nvim/commit/3da0b0ec11dff6c88e68c91194688c9ff3513e86))
* **win:** better way of finding a main window when fixbuf is `true` ([84ee7dd](https://github.com/folke/snacks.nvim/commit/84ee7ddf543aa1249ca4e29873200073e28f693f))
* **zen:** parent buf. Fixes [#720](https://github.com/folke/snacks.nvim/issues/720) ([f314676](https://github.com/folke/snacks.nvim/commit/f31467637ac91406efba15981d53cd6da09718e0))


### Performance Improvements

* **picker.frecency:** cache all deadlines on load ([5b3625b](https://github.com/folke/snacks.nvim/commit/5b3625bcea5ed78e7cddbeb038159a0041110c71))
* **picker:** gc optims ([3fa2ea3](https://github.com/folke/snacks.nvim/commit/3fa2ea3115c2e8203ec44025ff4be054c5f1e917))
* **picker:** small optims ([ee76e9b](https://github.com/folke/snacks.nvim/commit/ee76e9ba674e6b67a3d687868f27751745e2baad))
* **picker:** small optims for abort ([317a209](https://github.com/folke/snacks.nvim/commit/317a2093ea0cdd62a34f3a414e625f3313e5e2e8))
* **picker:** use picker ref in progress updater. Fixes [#710](https://github.com/folke/snacks.nvim/issues/710) ([37f3888](https://github.com/folke/snacks.nvim/commit/37f3888dccc922e4044ee1713c25dba51b4290d2))

## [2.14.0](https://github.com/folke/snacks.nvim/compare/v2.13.0...v2.14.0) (2025-01-20)


### Features

* **picker.buffer:** add filetype to bufname for buffers without name ([83baea0](https://github.com/folke/snacks.nvim/commit/83baea06d65d616f1f800501d0d82e4ad117abf2))
* **picker.debug:** debug option to detect garbage collection leaks ([b59f4ff](https://github.com/folke/snacks.nvim/commit/b59f4ff477a18cdc3673a240c2e992a2bccd48fe))
* **picker.matcher:** new `opts.matcher.file_pos` which defaults to `true` to support patterns like `file:line:col` or `file:line`. Closes [#517](https://github.com/folke/snacks.nvim/issues/517). Closes [#496](https://github.com/folke/snacks.nvim/issues/496). Closes [#651](https://github.com/folke/snacks.nvim/issues/651) ([5e00b0a](https://github.com/folke/snacks.nvim/commit/5e00b0ab271149f1bd74d5d5afe106b440f45a9d))
* **picker:** added `args` option for `files` and `grep`. Closes [#621](https://github.com/folke/snacks.nvim/issues/621) ([781b6f6](https://github.com/folke/snacks.nvim/commit/781b6f6ab0cd5f65a685bf8bac284f4a12e43589))
* **picker:** added `undo` picker to navigate the undo tree. Closes [#638](https://github.com/folke/snacks.nvim/issues/638) ([5c45f1c](https://github.com/folke/snacks.nvim/commit/5c45f1c193f2ed2fa639146df373f341d7410e8b))
* **picker:** added support for item.resolve that gets called if needed during list rendering / preview ([b0d3266](https://github.com/folke/snacks.nvim/commit/b0d32669856b8ad9c75fa7c6c4b643566001c8bc))
* **terminal:** allow overriding default shell. Closes [#450](https://github.com/folke/snacks.nvim/issues/450) ([3146fd1](https://github.com/folke/snacks.nvim/commit/3146fd139b89760526f32fd9d3ac4c91af010f0c))
* **terminal:** close terminals on `ExitPre`. Fixes [#419](https://github.com/folke/snacks.nvim/issues/419) ([2abf208](https://github.com/folke/snacks.nvim/commit/2abf208f2c43a387ca6c55c33b5ebbc7869c189c))


### Bug Fixes

* **dashboard:** added optional filter for recent files ([32cd343](https://github.com/folke/snacks.nvim/commit/32cd34383c8ac5d0e43408aba559308546555962))
* **debug.run:** schedule only nvim_buf_set_extmark in on_print ([#425](https://github.com/folke/snacks.nvim/issues/425)) ([81572b5](https://github.com/folke/snacks.nvim/commit/81572b5f97c3cb2f2e254972762f4b816e790fde))
* **indent:** use correct hl based on indent. Fixes [#422](https://github.com/folke/snacks.nvim/issues/422) ([627af73](https://github.com/folke/snacks.nvim/commit/627af7342cf5bea06793606c33992d2cc882655b))
* **input:** put the cursor right after the default prompt ([#549](https://github.com/folke/snacks.nvim/issues/549)) ([f904481](https://github.com/folke/snacks.nvim/commit/f904481439706e678e93225372b30f97281cfc2c))
* **notifier:** added `SnacksNotifierMinimal`. Closes [#410](https://github.com/folke/snacks.nvim/issues/410) ([daa575e](https://github.com/folke/snacks.nvim/commit/daa575e3cd42f003e171dbb8a3e992e670d5032c))
* **notifier:** win:close instead of win:hide ([f29f7a4](https://github.com/folke/snacks.nvim/commit/f29f7a433a2d9ea95f43c163d57df2f647700115))
* **picker.buffers:** add buf number to text ([70106a7](https://github.com/folke/snacks.nvim/commit/70106a79306525a281a3156bae1499f70c183d1d))
* **picker.buffer:** unselect on delete. Fixes [#653](https://github.com/folke/snacks.nvim/issues/653) ([0ac5605](https://github.com/folke/snacks.nvim/commit/0ac5605bfbeb31cee4bb91a6ca7a2bfe8c4d468f))
* **picker.grep:** correctly insert args from pattern. See [#601](https://github.com/folke/snacks.nvim/issues/601) ([8601a8c](https://github.com/folke/snacks.nvim/commit/8601a8ced398145d95f118737b29f3bd5f7eb700))
* **picker.grep:** debug ([f0d51ce](https://github.com/folke/snacks.nvim/commit/f0d51ce03835815aba0a6d748b54c3277ff38b70))
* **picker.lsp.symbols:** only include filename for search with workspace symbols ([eb0e5b7](https://github.com/folke/snacks.nvim/commit/eb0e5b7efe603bea7a0823ffaed13c52b395d04b))
* **picker.lsp:** backward compat with Neovim 0.95 ([3df2408](https://github.com/folke/snacks.nvim/commit/3df2408713efdbc72f9a8fcedc8586aed50ab023))
* **picker.lsp:** lazy resolve item lsp locations. Fixes [#650](https://github.com/folke/snacks.nvim/issues/650) ([d0a0046](https://github.com/folke/snacks.nvim/commit/d0a0046e37d274d8acdfcde653f3cadb12be6ba1))
* **picker.preview:** disable relativenumber by default. Closes [#664](https://github.com/folke/snacks.nvim/issues/664) ([384b9a7](https://github.com/folke/snacks.nvim/commit/384b9a7a36b5e30959fd89d3d857855105f65611))
* **picker.preview:** off-by-one for cmd output ([da5556a](https://github.com/folke/snacks.nvim/commit/da5556aa6bceb3428700607ab3005e5b44cb8b2e))
* **picker.preview:** reset before notify ([e50f2e3](https://github.com/folke/snacks.nvim/commit/e50f2e39094d4511506329044713ac69541f4135))
* **picker.undo:** disable number and signcolumn in preview ([40cea79](https://github.com/folke/snacks.nvim/commit/40cea79697acc97c3e4f814ca99a2d261fd6a4ee))
* **picker.util:** item.resolve for nil item ([2ff21b4](https://github.com/folke/snacks.nvim/commit/2ff21b4394d1f34887cb3425e32f18a793b749c7))
* **picker.util:** relax pattern for args ([6b7705c](https://github.com/folke/snacks.nvim/commit/6b7705c7edc9b93f16179d1343f9b2ae062340f9))
* **scope:** parse treesitter injections. Closes [#430](https://github.com/folke/snacks.nvim/issues/430) ([985ada3](https://github.com/folke/snacks.nvim/commit/985ada3c14346cc6df6a6013564a6541c66f6ce9))
* **statusline:** fix status line cache key ([#656](https://github.com/folke/snacks.nvim/issues/656)) ([af55934](https://github.com/folke/snacks.nvim/commit/af559349e591afaaaf75a8b3ecf5ee6f6711dde0))
* **win:** always close created scratch buffers when win closes ([abd7e61](https://github.com/folke/snacks.nvim/commit/abd7e61b7395af10a7862cec5bc746253a3b7917))
* **zen:** properly handle close ([920a9d2](https://github.com/folke/snacks.nvim/commit/920a9d28f1b1bf5ca06755236f9bbb8853adfea8))
* **zen:** sync cursor with parent window ([#547](https://github.com/folke/snacks.nvim/issues/547)) ([ba45c28](https://github.com/folke/snacks.nvim/commit/ba45c280dd9a35a6441a89d830b72f7cc8849b74)), closes [#539](https://github.com/folke/snacks.nvim/issues/539)


### Performance Improvements

* **picker:** fixed some issues with closed pickers not always being garbage collected ([eebf44a](https://github.com/folke/snacks.nvim/commit/eebf44a34e9e004f988437116140712834efd745))

## [2.13.0](https://github.com/folke/snacks.nvim/compare/v2.12.0...v2.13.0) (2025-01-19)


### Features

* **picker.actions:** added support for action options. Fixes [#598](https://github.com/folke/snacks.nvim/issues/598) ([8035398](https://github.com/folke/snacks.nvim/commit/8035398e523588df7eac928fd23e6692522f6e1e))
* **picker.buffers:** del buffer with ctrl+x ([2479ff7](https://github.com/folke/snacks.nvim/commit/2479ff7cf41392130bd660fb787e3b1730863657))
* **picker.buffers:** delete buffers with dd ([2ab18a0](https://github.com/folke/snacks.nvim/commit/2ab18a0b9f425ccbc697adc53a01b26ea38abe0d))
* **picker.commands:** added builtin commands. Fixes [#634](https://github.com/folke/snacks.nvim/issues/634) ([ee988fa](https://github.com/folke/snacks.nvim/commit/ee988fa4b018ae617a16e2a4078b4586f08364f2))
* **picker.frecency:** cleanup old entries from sqlite3 database ([320a4a6](https://github.com/folke/snacks.nvim/commit/320a4a62a159f9d3177251e21d81cb96156291b9))
* **picker.git:** added `git_diff` picker for diff hunks ([#519](https://github.com/folke/snacks.nvim/issues/519)) ([cc69043](https://github.com/folke/snacks.nvim/commit/cc690436892d6ab0b8d5ee51ad60ff91c3a5d640))
* **picker.git:** git diff/show can now use native or neovim for preview. defaults to neovim. Closes [#500](https://github.com/folke/snacks.nvim/issues/500). Closes [#494](https://github.com/folke/snacks.nvim/issues/494). Closes [#491](https://github.com/folke/snacks.nvim/issues/491). Closes [#478](https://github.com/folke/snacks.nvim/issues/478) ([e36e6af](https://github.com/folke/snacks.nvim/commit/e36e6af96cb2ac0574199ab9d229735fb6d9f016))
* **picker.git:** stage/unstage files in git status with `&lt;tab&gt;` key ([0892db4](https://github.com/folke/snacks.nvim/commit/0892db4f42fc538df0a0b8fd66600d1e2d41b9e4))
* **picker.grep:** added `ft` (rg's `type`) and `regex` (rg's `--fixed-strings`) options ([0437cfd](https://github.com/folke/snacks.nvim/commit/0437cfd98ea9767836685ef8f100b7a758239624))
* **picker.list:** added debug option to show scores ([821e231](https://github.com/folke/snacks.nvim/commit/821e23101fdfcc28819e27596177eaa64eebf0c2))
* **picker.list:** added select_all action mapped to ctrl+a ([c9e2695](https://github.com/folke/snacks.nvim/commit/c9e2695969687285fbf53c86336b75c4dae3b609))
* **picker.list:** better way of highlighting field patterns ([924a988](https://github.com/folke/snacks.nvim/commit/924a988d9af72bf1abba122fa9f02a4eb917f15a))
* **picker.list:** make `conceallevel` configurable. Fixes [#635](https://github.com/folke/snacks.nvim/issues/635) ([d88eab6](https://github.com/folke/snacks.nvim/commit/d88eab6e3fec20e162f52e618114b869f561e3fd))
* **picker.lsp:** added `lsp_workspace_symbols`. Supports live search. Closes [#473](https://github.com/folke/snacks.nvim/issues/473) ([348307a](https://github.com/folke/snacks.nvim/commit/348307a82e4ae139fcb02b4cd4ae95dbf46f32c7))
* **picker.matcher:** added opts.matcher.sort_empty and opts.matcher.filename_bonus ([ed91078](https://github.com/folke/snacks.nvim/commit/ed91078625996106ddd31dfb4bac634d2895f61f))
* **picker.matcher:** better scoring algorithm based on fzf. Closes [#512](https://github.com/folke/snacks.nvim/issues/512). Fixes [#513](https://github.com/folke/snacks.nvim/issues/513) ([e4e2e88](https://github.com/folke/snacks.nvim/commit/e4e2e88c769d54094194d6e3d68fbfae87b20cbe))
* **picker.matcher:** integrate custom item scores ([7267e24](https://github.com/folke/snacks.nvim/commit/7267e2493b5962a550d874f142aaf64c3873fb7e))
* **picker.matcher:** moved length tiebreak to sorter instead ([d5ccb30](https://github.com/folke/snacks.nvim/commit/d5ccb301c1fe2adb874dd8f4f675797d983a8284))
* **picker.recent:** include open files in recent files. Closes [#487](https://github.com/folke/snacks.nvim/issues/487) ([96ffaba](https://github.com/folke/snacks.nvim/commit/96ffaba71bed87cf8bf75c6d945dedae3fa40af2))
* **picker.score:** prioritize matches in filenames ([5cf5ec1](https://github.com/folke/snacks.nvim/commit/5cf5ec1a314b38d4e361f7f26cb6eb14febd4d69))
* **picker.smart:** better frecency bonus ([74feefc](https://github.com/folke/snacks.nvim/commit/74feefc52284e2ebf93ad815ec5aaeec918d4dc2))
* **picker.sort:** default sorter can now sort by len of a field ([6ae87d9](https://github.com/folke/snacks.nvim/commit/6ae87d9f62a17124db9283c789b1bd968a55a85a))
* **picker.sources:** lines just sorts by score/idx. Smart sorts on empty ([be42182](https://github.com/folke/snacks.nvim/commit/be421822d5498ad962481b134e6272defff9118e))
* **picker:** add qflist_all action to send all even when already sel… ([#600](https://github.com/folke/snacks.nvim/issues/600)) ([c7354d8](https://github.com/folke/snacks.nvim/commit/c7354d83486d60d0a965426fa920d341759b69c6))
* **picker:** add some source aliases like the Telescope / FzfLua names ([5a83a8e](https://github.com/folke/snacks.nvim/commit/5a83a8e32885d6b923319cb8dc5ff1d1d97d0b10))
* **picker:** added `{preview}` and `{flags}` title placeholders. Closes [#557](https://github.com/folke/snacks.nvim/issues/557), Closes [#540](https://github.com/folke/snacks.nvim/issues/540) ([2e70b7f](https://github.com/folke/snacks.nvim/commit/2e70b7f42364e50df25407ddbd897e157a44c526))
* **picker:** added `git_branches` picker. Closes [#614](https://github.com/folke/snacks.nvim/issues/614) ([8563dfc](https://github.com/folke/snacks.nvim/commit/8563dfce682eeb260fa17e554b3e02de47e61f35))
* **picker:** added `inspect` action mapped to `&lt;c-i&gt;`. Useful to see what search fields are available on an item. ([2ba165b](https://github.com/folke/snacks.nvim/commit/2ba165b826d31ab0ebeaaff26632efe7013042b6))
* **picker:** added `smart` picker ([772f3e9](https://github.com/folke/snacks.nvim/commit/772f3e9b8970123db4050e9f7a5bdf2270575c6c))
* **picker:** added exclude option for files and grep. Closes [#581](https://github.com/folke/snacks.nvim/issues/581) ([192fb31](https://github.com/folke/snacks.nvim/commit/192fb31c4beda9aa4ebbc8bad0abe59df8bdde85))
* **picker:** added jump options jumplist(true for all), reuse_win & tagstack (true for lsp). Closes [#589](https://github.com/folke/snacks.nvim/issues/589). Closes [#568](https://github.com/folke/snacks.nvim/issues/568) ([84c3738](https://github.com/folke/snacks.nvim/commit/84c3738fb04fff83aba8e91c3af8ad9e74b089fd))
* **picker:** added preliminary support for combining finder results. More info coming soon ([000db17](https://github.com/folke/snacks.nvim/commit/000db17bf9f8bd243bbe944c0ae7e162d8cad572))
* **picker:** added spelling picker. Closes [#625](https://github.com/folke/snacks.nvim/issues/625) ([b170ced](https://github.com/folke/snacks.nvim/commit/b170ced527c03911a4658fb2df7139fa7040bcef))
* **picker:** added support for live args for `grep` and `files`. Closes [#601](https://github.com/folke/snacks.nvim/issues/601) ([50f3c3e](https://github.com/folke/snacks.nvim/commit/50f3c3e5b1c52c223a2689b1b2828c1ddae9e866))
* **picker:** added toggle/flag/action for `follow`. Closes [#633](https://github.com/folke/snacks.nvim/issues/633) ([aa53f6c](https://github.com/folke/snacks.nvim/commit/aa53f6c0799f1f6b80f6fb46472ec4773763f6b8))
* **picker:** allow disabling file icons ([76fbf9e](https://github.com/folke/snacks.nvim/commit/76fbf9e8a85485abfe1c53d096c74faad3fa2a6b))
* **picker:** allow setting a custom `opts.title`. Fixes [#620](https://github.com/folke/snacks.nvim/issues/620) ([6001fb2](https://github.com/folke/snacks.nvim/commit/6001fb2077306655afefba6593ec8b55e18abc39))
* **picker:** custom icon for unselected entries ([#588](https://github.com/folke/snacks.nvim/issues/588)) ([6402687](https://github.com/folke/snacks.nvim/commit/64026877ad8dac658eb5056e0c56f66e17401bdb))
* **picker:** restore cursor / topline on resume ([ca54948](https://github.com/folke/snacks.nvim/commit/ca54948f79917113dfcdf1c4ccaec573244a02aa))
* **pickers.format:** added `opts.picker.formatters.file.filename_first` ([98562ae](https://github.com/folke/snacks.nvim/commit/98562ae6a112bf1d80a9bec7fb2849605234a9d5))
* **picker:** use an sqlite3 database for frecency data when available ([c43969d](https://github.com/folke/snacks.nvim/commit/c43969dabd42e261c570f533c2f343f99a9d1f01))
* **scroll:** faster animations for scroll repeats after delay. (replaces spamming handling) ([d494a9e](https://github.com/folke/snacks.nvim/commit/d494a9e66447e9ae22e40c374e2e7d9a24b64d93))
* **snacks:** added `snacks.picker` ([#445](https://github.com/folke/snacks.nvim/issues/445)) ([559d6c6](https://github.com/folke/snacks.nvim/commit/559d6c6bf207e4e768a88e7f727ac12a87c768b7))
* **toggle:** allow toggling global options. Fixes [#534](https://github.com/folke/snacks.nvim/issues/534) ([b50effc](https://github.com/folke/snacks.nvim/commit/b50effc96763f0b84473b68c733ef3eff8a14be5))
* **win:** warn on duplicate keymaps that differ in case. See [#554](https://github.com/folke/snacks.nvim/issues/554) ([a71b7c0](https://github.com/folke/snacks.nvim/commit/a71b7c0d26b578ad2b758ad74139b2ddecf8c15f))


### Bug Fixes

* **animate:** never animate stopped animations ([197b0a9](https://github.com/folke/snacks.nvim/commit/197b0a9be93a6fa49b840fe159ce6373c7edcf98))
* **bigfile:** check existence of NoMatchParen before executing ([#561](https://github.com/folke/snacks.nvim/issues/561)) ([9b8f57b](https://github.com/folke/snacks.nvim/commit/9b8f57b96f823b83848572bf3384754f8ab46217))
* **config:** better vim.tbl_deep_extend that prevents issues with list-like tables. Fixes [#554](https://github.com/folke/snacks.nvim/issues/554) ([75eb16f](https://github.com/folke/snacks.nvim/commit/75eb16fd9c746bbd5e21992b6eb986d389dd246e))
* **config:** dont exclude metatables ([2d4a0b5](https://github.com/folke/snacks.nvim/commit/2d4a0b594a69c535704c15fc41c74d18c5f4d08b))
* **grep:** explicitely set `--no-hidden` because of the git filter ([ae2de9a](https://github.com/folke/snacks.nvim/commit/ae2de9aa8101dbff1ee1ab101d53e916f6e217dd))
* **indent:** dont redraw when list/shiftwidth/listchars change. Triggered way too often. Fixes [#613](https://github.com/folke/snacks.nvim/issues/613). Closes [#627](https://github.com/folke/snacks.nvim/issues/627) ([d212e3c](https://github.com/folke/snacks.nvim/commit/d212e3c99090eec3211e84e526b9fbdd000e020c))
* **input:** bring back `&lt;c-w&gt;`. Fixes [#426](https://github.com/folke/snacks.nvim/issues/426). Closes [#429](https://github.com/folke/snacks.nvim/issues/429) ([5affa72](https://github.com/folke/snacks.nvim/commit/5affa7214f621144526b9a7d93b83302fa6ea6f4))
* **layout:** allow root with relative=cursor. Closes [#479](https://github.com/folke/snacks.nvim/issues/479) ([f06f14c](https://github.com/folke/snacks.nvim/commit/f06f14c4ae4d131eb5e15f4c49994f8debddff42))
* **layout:** don't trigger events during re-layout on resize. Fixes [#552](https://github.com/folke/snacks.nvim/issues/552) ([d73a4a6](https://github.com/folke/snacks.nvim/commit/d73a4a64dfd203b9f3a4a9dedd76af398faa6652))
* **layout:** open/update windows in order of the layout to make sure offsets are correct ([034d50d](https://github.com/folke/snacks.nvim/commit/034d50d44e98af433260292001a88ac54d2466b6))
* **layout:** use eventignore when updating windows that are already visible to fix issues with synatx. Fixes [#552](https://github.com/folke/snacks.nvim/issues/552) ([f7d967c](https://github.com/folke/snacks.nvim/commit/f7d967c5157ee621168153502812a266c509bd97))
* **lsp:** use treesitter highlights for LSP locations ([fc06a36](https://github.com/folke/snacks.nvim/commit/fc06a363b95312eba0f3335f1190c745d0e5ea26))
* **notifier:** content width. Fixes [#631](https://github.com/folke/snacks.nvim/issues/631) ([0e27737](https://github.com/folke/snacks.nvim/commit/0e277379ea7d25c97d109d31da33abacf26da841))
* **picker.actions:** added hack to make folds work. Fixes [#514](https://github.com/folke/snacks.nvim/issues/514) ([df1060f](https://github.com/folke/snacks.nvim/commit/df1060fa501d06758d588a341d5cdec650cbfc67))
* **picker.actions:** close existing empty buffer if it's the current buffer ([0745505](https://github.com/folke/snacks.nvim/commit/0745505f2f43d2983867f48805bd4f700ad06c73))
* **picker.actions:** full path for qflist and loclist actions ([3e39250](https://github.com/folke/snacks.nvim/commit/3e392507963f784a4d57708585f8e012f1b95768))
* **picker.actions:** only delete empty buffer if it's not displayed in a window. Fixes [#566](https://github.com/folke/snacks.nvim/issues/566) ([b7ab888](https://github.com/folke/snacks.nvim/commit/b7ab888dd0c5bb0bafe9d01209f6a63320621b11))
* **picker.actions:** return action result. Fixes [#612](https://github.com/folke/snacks.nvim/issues/612). See [#611](https://github.com/folke/snacks.nvim/issues/611) ([4a482be](https://github.com/folke/snacks.nvim/commit/4a482bea3c5cac7af66a7a3d5cee5f97fca6c9d8))
* **picker.colorscheme:** nil check. Fixes [#575](https://github.com/folke/snacks.nvim/issues/575) ([de01907](https://github.com/folke/snacks.nvim/commit/de01907930bb125d1b67b4a1fb372f21d972f70b))
* **picker.config:** allow merging list-like layouts with table layout options ([706b1ab](https://github.com/folke/snacks.nvim/commit/706b1abc1697ca050314dc667e0900d53cad8aa4))
* **picker.config:** better config merging and tests ([9986b47](https://github.com/folke/snacks.nvim/commit/9986b47707bbe76cf3b901c3048e55b2ba2bb4a8))
* **picker.config:** normalize keys before merging so you can override `&lt;c-s&gt;` with `<C-S>` ([afef949](https://github.com/folke/snacks.nvim/commit/afef949d88b6fa3dde8515b27066b132cfdb0a70))
* **picker.db:** remove tests ([71f69e5](https://github.com/folke/snacks.nvim/commit/71f69e5e57f355f40251e274d45560af7d8dd365))
* **picker.diagnostics:** sort on empty pattern. Fixes [#641](https://github.com/folke/snacks.nvim/issues/641) ([c6c76a6](https://github.com/folke/snacks.nvim/commit/c6c76a6aa338af47e2725cff35cc814fcd2ad1e7))
* **picker.files:** ignore errors since it's not possible to know if the error isbecause of an incomplete pattern. Fixes [#551](https://github.com/folke/snacks.nvim/issues/551) ([4823f2d](https://github.com/folke/snacks.nvim/commit/4823f2da65a5e11c10242af5e0d1c977474288b3))
* **picker.format:** filename ([a194bbc](https://github.com/folke/snacks.nvim/commit/a194bbc3747f73416ec2fd25cb39c233fcc7a656))
* **picker.format:** use forward slashes for paths. Closes [#624](https://github.com/folke/snacks.nvim/issues/624) ([5f82ffd](https://github.com/folke/snacks.nvim/commit/5f82ffde0befbcbfbedb9b5066bf4f3a5d667495))
* **picker.git:** git log file/line for a file not in cwd. Fixes [#616](https://github.com/folke/snacks.nvim/issues/616) ([9034319](https://github.com/folke/snacks.nvim/commit/903431903b0151f97f45087353ebe8fa1cb8ef80))
* **picker.git:** git_file and git_line should only show diffs including the file. Fixes [#522](https://github.com/folke/snacks.nvim/issues/522) ([1481a90](https://github.com/folke/snacks.nvim/commit/1481a90affedb24291997f5ebde0637cafc1d20e))
* **picker.git:** use Snacks.git.get_root instead vim.fs.root for backward compatibility ([a2fb70e](https://github.com/folke/snacks.nvim/commit/a2fb70e8ba2bb2ce5c60ed1ee7505d6f6d7be061))
* **picker.highlight:** properly deal with multiline treesitter captures ([27b72ec](https://github.com/folke/snacks.nvim/commit/27b72ecd005743ecf5855cd3b430fce74bd4f2e3))
* **picker.input:** don't set prompt interrupt, but use a `&lt;c-c&gt;` mapping instead that can be changed ([123f0d9](https://github.com/folke/snacks.nvim/commit/123f0d9e5d7be5b23ef9b28b9ddde403e4b2d061))
* **picker.input:** leave insert mode when closing and before executing confirm. Fixes [#543](https://github.com/folke/snacks.nvim/issues/543) ([05eb22c](https://github.com/folke/snacks.nvim/commit/05eb22c4fbe09f9bed53a752301d5c2a8a060a4e))
* **picker.input:** statuscolumn on resize / re-layout. Fixes [#643](https://github.com/folke/snacks.nvim/issues/643) ([4d8d844](https://github.com/folke/snacks.nvim/commit/4d8d844027a3ea04ac7ecb0ab6cd63e39e96d06f))
* **picker.input:** strip newllines from pattern (mainly due to pasting in the input box) ([c6a9955](https://github.com/folke/snacks.nvim/commit/c6a9955516b686d1b6bd815e1df0c808baa60bd3))
* **picker.input:** use `Snacks.util.wo` instead of `vim.wo`. Fixes [#643](https://github.com/folke/snacks.nvim/issues/643) ([d6284d5](https://github.com/folke/snacks.nvim/commit/d6284d51ff748f43c5431c35ffed7f7c02e51069))
* **picker.list:** disable folds ([5582a84](https://github.com/folke/snacks.nvim/commit/5582a84020a1e11d9001660252cdee6a424ba159))
* **picker.list:** include `search` filter for highlighting items (live search). See [#474](https://github.com/folke/snacks.nvim/issues/474) ([1693fbb](https://github.com/folke/snacks.nvim/commit/1693fbb0dcf1b82f2212a325379ebb0257d582e5))
* **picker.list:** newlines in text. Fixes [#607](https://github.com/folke/snacks.nvim/issues/607). Closes [#580](https://github.com/folke/snacks.nvim/issues/580) ([c45a940](https://github.com/folke/snacks.nvim/commit/c45a94044b8e4c9f5deb420a7caa505281e1eed5))
* **picker.list:** possible issue with window options being set in the wrong window ([f1b6c55](https://github.com/folke/snacks.nvim/commit/f1b6c55027c6e75940fcb40fa8ac5ab717de1647))
* **picker.list:** scores debug ([9499b94](https://github.com/folke/snacks.nvim/commit/9499b944e79ff305769a59819c44a93911023fc7))
* **picker.lsp:** added support for single location result ([79d27f1](https://github.com/folke/snacks.nvim/commit/79d27f19dc62c0978d2688c6fac9348f253ef007))
* **picker.matcher:** initialize matcher with pattern from opts. Fixes [#596](https://github.com/folke/snacks.nvim/issues/596) ([c434eb8](https://github.com/folke/snacks.nvim/commit/c434eb89fe030672f4e518b4de1e506ffaf0e96e))
* **picker.matcher:** inverse scores ([1816931](https://github.com/folke/snacks.nvim/commit/1816931aadb1fdcd3e08606d773d31f3d51fabcc))
* **picker.minheap:** clear sorted on minheap clear. Fixes [#492](https://github.com/folke/snacks.nvim/issues/492) ([79bea58](https://github.com/folke/snacks.nvim/commit/79bea58b1ec92909d763c8b5788baf8da6c19a06))
* **picker.preview:** don't show line numbers for preview commands ([a652214](https://github.com/folke/snacks.nvim/commit/a652214f52694233b5e27d374db0d51d2f7cb43d))
* **picker.preview:** pattern to detect binary files was incorrect ([bbd1a08](https://github.com/folke/snacks.nvim/commit/bbd1a0885b3e89103a8a59f1f07d296f23c7d2ad))
* **picker.preview:** scratch buffer filetype. Fixes [#595](https://github.com/folke/snacks.nvim/issues/595) ([ece76b3](https://github.com/folke/snacks.nvim/commit/ece76b333a9ff372959bf5204ab22f58215383c1))
* **picker.proc:** correct offset for carriage returns. Fixes [#599](https://github.com/folke/snacks.nvim/issues/599) ([a01e0f5](https://github.com/folke/snacks.nvim/commit/a01e0f536815a0cc23443fae5ac10f7fdcb4f313))
* **picker.qf:** better quickfix item list. Fixes [#562](https://github.com/folke/snacks.nvim/issues/562) ([cb84540](https://github.com/folke/snacks.nvim/commit/cb845408dbc795582ea1567fba2bf4ba64c777ac))
* **picker.select:** allow main to be current. Fixes [#497](https://github.com/folke/snacks.nvim/issues/497) ([076259d](https://github.com/folke/snacks.nvim/commit/076259d263c927ed1d1c56c94b6e870230e77a3d))
* **picker.util:** cleanup func for key-value store (frecency) ([bd2da45](https://github.com/folke/snacks.nvim/commit/bd2da45c384ea7ce44bdd15a7b5e32ee3806cf8d))
* **picker:** add alias for `oldfiles` ([46554a6](https://github.com/folke/snacks.nvim/commit/46554a63425c0594eacaa0e8eaddec5dbf79b48e))
* **picker:** add keymaps for preview scratch buffers ([dc3f114](https://github.com/folke/snacks.nvim/commit/dc3f114c1f787218e4314d907866874a62253756))
* **picker:** always stopinsert, even when picker is already closed. Should not be needed, but some plugins misbehave. See  [#579](https://github.com/folke/snacks.nvim/issues/579) ([29becb0](https://github.com/folke/snacks.nvim/commit/29becb0ecbeb20683b3ae71d4c082734b2f518af))
* **picker:** better buffer edit. Fixes [#593](https://github.com/folke/snacks.nvim/issues/593) ([716492c](https://github.com/folke/snacks.nvim/commit/716492c57870e11e04a5764bcc1e549859f563be))
* **picker:** better normkey. Fixes [#610](https://github.com/folke/snacks.nvim/issues/610) ([540ecbd](https://github.com/folke/snacks.nvim/commit/540ecbd9a4b4c4d4ed47db83367f9e5d04220c27))
* **picker:** changed inspect mapping to `&lt;a-d&gt;` since not all terminal differentiate between `<a-i>` and `<tab>` ([8386540](https://github.com/folke/snacks.nvim/commit/8386540c422774059a75fe26ce7cfb6ab3811c73))
* **picker:** correctly normalize path after fnamemodify ([f351dcf](https://github.com/folke/snacks.nvim/commit/f351dcfcaca069d5f70bcf6edbde244e7358d063))
* **picker:** deepcopy before config merging. Fixes [#554](https://github.com/folke/snacks.nvim/issues/554) ([7865df0](https://github.com/folke/snacks.nvim/commit/7865df0558fa24cce9ec27c4e002d5e179cab685))
* **picker:** don't throttle preview if it's the first item we're previewing ([b785167](https://github.com/folke/snacks.nvim/commit/b785167814c5481643b53d241487fc9802a1ab13))
* **picker:** dont fast path matcher when finder items have scores ([2ba5602](https://github.com/folke/snacks.nvim/commit/2ba5602834830e1a96e4f1a81e0fbb310481ca74))
* **picker:** format: one too many spaces for default icon in results … ([#594](https://github.com/folke/snacks.nvim/issues/594)) ([d7f727f](https://github.com/folke/snacks.nvim/commit/d7f727f673a67b60882a3d2a96db4d1490566e73))
* **picker:** picker:items() should return filtered items, not finder items. Closes [#481](https://github.com/folke/snacks.nvim/issues/481) ([d67e093](https://github.com/folke/snacks.nvim/commit/d67e093bbc2a2069c5e6118babf99c9029b34675))
* **picker:** potential issue with preview winhl being set on the main window ([34208eb](https://github.com/folke/snacks.nvim/commit/34208ebe00a237a232a6050f81fb89f25d473180))
* **picker:** preview / lsp / diagnostics positions were wrong; Should all be (1-0) indexed. Fixes [#543](https://github.com/folke/snacks.nvim/issues/543) ([40d08bd](https://github.com/folke/snacks.nvim/commit/40d08bd901db740f4b270fb6e9b710312a2846df))
* **picker:** properly handle `opts.layout` being a string. Fixes [#636](https://github.com/folke/snacks.nvim/issues/636) ([b80c9d2](https://github.com/folke/snacks.nvim/commit/b80c9d275d05778c90df32bd361c8630b28d13fd))
* **picker:** select_and_prev should use list_up instead of list_down ([#471](https://github.com/folke/snacks.nvim/issues/471)) ([b993be7](https://github.com/folke/snacks.nvim/commit/b993be762ba9aa9c1efd858ae777eef3de28c609))
* **picker:** set correct cwd for git status picker ([#505](https://github.com/folke/snacks.nvim/issues/505)) ([2cc7cf4](https://github.com/folke/snacks.nvim/commit/2cc7cf42e94041c08f5654935f745424d10a15b1))
* **picker:** show all files in git status ([#586](https://github.com/folke/snacks.nvim/issues/586)) ([43c312d](https://github.com/folke/snacks.nvim/commit/43c312dfc1433b3bdf24c7a14bc0aac648fa8d33))
* **scope:** make sure to parse the ts tree. Fixes [#521](https://github.com/folke/snacks.nvim/issues/521) ([4c55f1c](https://github.com/folke/snacks.nvim/commit/4c55f1c2da103e4c2776274cb0f6fab0318ea811))
* **scratch:** autowrite right buffer. Fixes [#449](https://github.com/folke/snacks.nvim/issues/449). ([#452](https://github.com/folke/snacks.nvim/issues/452)) ([8d2e26c](https://github.com/folke/snacks.nvim/commit/8d2e26cf27330ead517193f7eeb898d189a973c2))
* **scroll:** don't animate for new changedtick. Fixes [#384](https://github.com/folke/snacks.nvim/issues/384) ([ac8b3cd](https://github.com/folke/snacks.nvim/commit/ac8b3cdfa08c2bba065c95b512887d3bbea91807))
* **scroll:** don't animate when recording or executing macros ([7dcdcb0](https://github.com/folke/snacks.nvim/commit/7dcdcb0b6ab6ecb2c6efdbaa4769bc03f5837832))
* **statuscolumn:** return "" when no signs and no numbers are needed. Closes [#570](https://github.com/folke/snacks.nvim/issues/570). ([c4980ef](https://github.com/folke/snacks.nvim/commit/c4980ef9b4e678d4057ece6fd2c13637a395f3a0))
* **util:** normkey ([cd58a14](https://github.com/folke/snacks.nvim/commit/cd58a14e20fdcd810b55e8aee535486a3ad8719f))
* **win:** clear syntax when setting filetype ([c49f38c](https://github.com/folke/snacks.nvim/commit/c49f38c5a919400689ab11669d45331f210ea91c))
* **win:** correctly deal with initial text containing newlines. Fixes [#542](https://github.com/folke/snacks.nvim/issues/542) ([825c106](https://github.com/folke/snacks.nvim/commit/825c106f40352dc2979724643e0d36af3a962eb1))
* **win:** duplicate keymap should take mode into account. Closes [#559](https://github.com/folke/snacks.nvim/issues/559) ([097e68f](https://github.com/folke/snacks.nvim/commit/097e68fc720a8fcdb370e6ccd2a3acad40b98952))
* **win:** exclude cursor from redraw. Fixes [#613](https://github.com/folke/snacks.nvim/issues/613) ([ad9b382](https://github.com/folke/snacks.nvim/commit/ad9b382f7d0e150d2420cb65d44d6fb81a6b62c8))
* **win:** fix relative=cursor again ([5b1cd46](https://github.com/folke/snacks.nvim/commit/5b1cd464e8759156d4d69f0398a0f5b34fa0b743))
* **win:** relative=cursor. Closes [#427](https://github.com/folke/snacks.nvim/issues/427). Closes [#477](https://github.com/folke/snacks.nvim/issues/477) ([743f8b3](https://github.com/folke/snacks.nvim/commit/743f8b3fee780780d8e201960a4a295dc5187e9b))
* **win:** special handling of `&lt;C-J&gt;`. Closes [#565](https://github.com/folke/snacks.nvim/issues/565). Closes [#592](https://github.com/folke/snacks.nvim/issues/592) ([5ac80f0](https://github.com/folke/snacks.nvim/commit/5ac80f0159239e44448fa9b08d8462e93342192d))
* **win:** win position with border offsets. Closes [#413](https://github.com/folke/snacks.nvim/issues/413). Fixes [#423](https://github.com/folke/snacks.nvim/issues/423) ([ee08b1f](https://github.com/folke/snacks.nvim/commit/ee08b1f32e06904318f8fa24714557d3abcdd215))
* **words:** added support for new name of the namespace used for lsp references. Fixes [#555](https://github.com/folke/snacks.nvim/issues/555) ([566f302](https://github.com/folke/snacks.nvim/commit/566f3029035143c525c0df7f5e7bbf9b3e939f54))


### Performance Improvements

* **notifier:** skip processing during search. See [#627](https://github.com/folke/snacks.nvim/issues/627) ([cf5f56a](https://github.com/folke/snacks.nvim/commit/cf5f56a1d82f4ece762843334c744e5830f4b4ef))
* **picker.matcher:** fast path when we already found a perfect match ([6bbf50c](https://github.com/folke/snacks.nvim/commit/6bbf50c5e3a3ab3bfc6a6747f6a2c66cbc9b7548))
* **picker.matcher:** only use filename_bonus for items that have a file field ([fd854ab](https://github.com/folke/snacks.nvim/commit/fd854ab9efdd13cf9cda192838f967551f332e36))
* **picker.matcher:** yield every 1ms to prevent ui locking in large repos ([19979c8](https://github.com/folke/snacks.nvim/commit/19979c88f37930f71bd98b96e1afa50ae26a09ae))
* **picker.util:** cache path calculation ([7117356](https://github.com/folke/snacks.nvim/commit/7117356b49ceedd7185c43a732dfe10c6a60cdbc))
* **picker:** dont use prompt buffer callbacks ([8293add](https://github.com/folke/snacks.nvim/commit/8293add1e524f48aee1aacd68f72d4204096aed2))
* **picker:** matcher optims ([5295741](https://github.com/folke/snacks.nvim/commit/529574128783c0fc4a146b207ea532950f48732f))

## [2.12.0](https://github.com/folke/snacks.nvim/compare/v2.11.0...v2.12.0) (2025-01-05)


### Features

* **debug:** system & memory metrics useful for debugging ([cba16bd](https://github.com/folke/snacks.nvim/commit/cba16bdb35199c941c8d78b8fb9ddecf568c0b1f))
* **input:** disable completion engines in input ([37038df](https://github.com/folke/snacks.nvim/commit/37038df00d6b47a65de24266c25683ff5a781a40))
* **scope:** disable treesitter blocks by default ([8ec6e6a](https://github.com/folke/snacks.nvim/commit/8ec6e6adc5b098674c41005530d1c8af126480ae))
* **statuscolumn:** allow changing the marks hl group. Fixes [#390](https://github.com/folke/snacks.nvim/issues/390) ([8a6e5b9](https://github.com/folke/snacks.nvim/commit/8a6e5b9685bb8c596a179256b048043a51a64e09))
* **util:** `Snacks.util.ref` ([7383eda](https://github.com/folke/snacks.nvim/commit/7383edaec842609deac50b114a3567c2983b54f4))
* **util:** throttle ([737980d](https://github.com/folke/snacks.nvim/commit/737980d987cdb4d3c2b18e0b3b8613fde974a2e9))
* **win:** `Snacks.win:border_size` ([4cd0647](https://github.com/folke/snacks.nvim/commit/4cd0647eb5bda07431e125374c1419059783a741))
* **win:** `Snacks.win:redraw` ([0711a82](https://github.com/folke/snacks.nvim/commit/0711a82b7a77c0ab35251e28cf1a7be0b3bde6d4))
* **win:** `Snacks.win:scroll` ([a1da66e](https://github.com/folke/snacks.nvim/commit/a1da66e3bf2768273f1dfb556b29269fd8ba153d))
* **win:** allow setting `desc` for window actions ([402494b](https://github.com/folke/snacks.nvim/commit/402494bdee8800c8ac3eeceb8c5e78e00f72f265))
* **win:** better dimension calculation for windows (use by upcoming layouts) ([cc0b528](https://github.com/folke/snacks.nvim/commit/cc0b52872b99e3af7d80536e8a9cbc28d47e7f19))
* **win:** top,right,bottom,left borders ([320ecbc](https://github.com/folke/snacks.nvim/commit/320ecbc15c25a240fee2c2970f826259d809ed72))


### Bug Fixes

* **dashboard:** hash dashboard terminal section caching key to support long commands ([#381](https://github.com/folke/snacks.nvim/issues/381)) ([d312053](https://github.com/folke/snacks.nvim/commit/d312053f78b4fb55523def179ac502438dd93193))
* **debug:** make debug.inpect work in fast events ([b70edc2](https://github.com/folke/snacks.nvim/commit/b70edc29dbc8c9718af246a181b05d4d190ad260))
* **debug:** make sure debug can be required in fast events ([6cbdbb9](https://github.com/folke/snacks.nvim/commit/6cbdbb9afa748e84af4c35d17fc4737b18638a35))
* **indent:** allow rendering over blank lines. Fixes [#313](https://github.com/folke/snacks.nvim/issues/313) ([766e671](https://github.com/folke/snacks.nvim/commit/766e67145259e30ae7d63dfd6d51b8d8ef0840ae))
* **indent:** better way to deal with `breakindent`. Fixes [#329](https://github.com/folke/snacks.nvim/issues/329) ([235427a](https://github.com/folke/snacks.nvim/commit/235427abcbf3e2b251a8b75f0e409dfbb6c737d6))
* **indent:** breakdinent ([972c61c](https://github.com/folke/snacks.nvim/commit/972c61cc1cd254ef3b43ec1dfd51eefbdc441a7d))
* **indent:** correct calculation of partial indent when leftcol &gt; 0 ([6f3cbf8](https://github.com/folke/snacks.nvim/commit/6f3cbf8ad328d181a694cdded344477e81cd094d))
* **indent:** do animate check in bufcall ([c62e7a2](https://github.com/folke/snacks.nvim/commit/c62e7a2561351c9fe3a8e7e9fc8602f3b61abf53))
* **indent:** don't render scopes in closed folds. Fixes [#352](https://github.com/folke/snacks.nvim/issues/352) ([94ec568](https://github.com/folke/snacks.nvim/commit/94ec5686a64218c9477de7761af4fd34dd4a665b))
* **indent:** off-by-one for indent guide hl group ([551e644](https://github.com/folke/snacks.nvim/commit/551e644ca311d065b3a6882db900846c1e66e636))
* **indent:** repeat_linbebreak only works on Neovim &gt;= 0.10. Fixes [#353](https://github.com/folke/snacks.nvim/issues/353) ([b93201b](https://github.com/folke/snacks.nvim/commit/b93201bdf36bd62b07daf7d40bc305998f9da52c))
* **indent:** simplify indent guide logic and never overwrite blanks. Fixes [#334](https://github.com/folke/snacks.nvim/issues/334) ([282be8b](https://github.com/folke/snacks.nvim/commit/282be8bfa8e6f46d6994ff46638d1c155b90753f))
* **indent:** typo for underline ([66cce2f](https://github.com/folke/snacks.nvim/commit/66cce2f512e11a961a8f187eac802acbf8725d05))
* **indent:** use space instead of full blank for indent offset. See [#313](https://github.com/folke/snacks.nvim/issues/313) ([58081bc](https://github.com/folke/snacks.nvim/commit/58081bcecb31db8c6f12ad876c70786582a7f6a8))
* **input:** change buftype to prompt. Fixes [#350](https://github.com/folke/snacks.nvim/issues/350) ([2990bf0](https://github.com/folke/snacks.nvim/commit/2990bf0c7a79f5780a0268a47bae69ef004cec99))
* **input:** make sure to show input window with a higher zindex of the parent window (if float) ([3123e6e](https://github.com/folke/snacks.nvim/commit/3123e6e9882f178411ea6e9fbf5e9552134b82b0))
* **input:** refactor for win changes and ensure modified=false. Fixes [#403](https://github.com/folke/snacks.nvim/issues/403). Fixes [#402](https://github.com/folke/snacks.nvim/issues/402) ([8930630](https://github.com/folke/snacks.nvim/commit/89306308f357e12510683758c35d08f368db2b2c))
* **input:** use correct highlight group for input prompt ([#328](https://github.com/folke/snacks.nvim/issues/328)) ([818da33](https://github.com/folke/snacks.nvim/commit/818da334ac8f655235b5861bb50577921e4e6bd8))
* **lazygit:** enable boolean values in config ([#377](https://github.com/folke/snacks.nvim/issues/377)) ([ec34684](https://github.com/folke/snacks.nvim/commit/ec346843e0adb51b45e595dd0ef34bf9e64d4627))
* **notifier:** open history window with correct style ([#307](https://github.com/folke/snacks.nvim/issues/307)) ([d2b5680](https://github.com/folke/snacks.nvim/commit/d2b5680359ee8feb34b095fd574b4f9b3f013629))
* **notifier:** rename style `notification.history` -&gt; `notification_history` ([fd9ef30](https://github.com/folke/snacks.nvim/commit/fd9ef30206185e3dd4d3294c74e2fd0dee9722d1))
* **scope:** allow treesitter scopes when treesitter highlighting is disabled. See [#231](https://github.com/folke/snacks.nvim/issues/231) ([58ae580](https://github.com/folke/snacks.nvim/commit/58ae580c2c12275755bb3e2003aebd06d550f2db))
* **scope:** don't expand to invalid range. Fixes [#339](https://github.com/folke/snacks.nvim/issues/339) ([1244305](https://github.com/folke/snacks.nvim/commit/1244305bedb8e60a946d949c78453263a714a4ad))
* **scope:** properly caluclate start indent when `cursor=true` for indent scopes. See [#5068](https://github.com/folke/snacks.nvim/issues/5068) ([e63fa7b](https://github.com/folke/snacks.nvim/commit/e63fa7bf05d22f4306c5fff594d48bc01e382238))
* **scope:** use virtcol for calculating scopes at the cursor ([6a36f32](https://github.com/folke/snacks.nvim/commit/6a36f32eaa7d5d59e681b7b8112a85a58a2d563d))
* **scroll:** check for invalid window. Fixes [#340](https://github.com/folke/snacks.nvim/issues/340) ([b6032e8](https://github.com/folke/snacks.nvim/commit/b6032e8f1b5cba55b5a2cf138ab4f172c4decfbd))
* **scroll:** don't animate when leaving cmdline search with incsearch enabled. Fixes [#331](https://github.com/folke/snacks.nvim/issues/331) ([fc0a99b](https://github.com/folke/snacks.nvim/commit/fc0a99b8493c34e6a930b3571ee8491e23831bca))
* **util:** throttle now autonatically schedules when in fast event ([9840331](https://github.com/folke/snacks.nvim/commit/98403313c749e26e5ae9a8ff51343c97f76ce170))
* **win:** backdrop having bright cell at top right ([#400](https://github.com/folke/snacks.nvim/issues/400)) ([373d0f9](https://github.com/folke/snacks.nvim/commit/373d0f9b6d6d83cdba641937b6303b0a0a18119f))
* **win:** don't enter when focusable is `false` ([ca233c7](https://github.com/folke/snacks.nvim/commit/ca233c7448c930658e8c7da9745e8d98884c3852))
* **win:** force-close any buffer that is not a file ([dd50e53](https://github.com/folke/snacks.nvim/commit/dd50e53a9efea11329e21c4a61ca35ae5122ceca))
* **win:** unset `winblend` when transparent ([0617e28](https://github.com/folke/snacks.nvim/commit/0617e28f8289002310fed5986acc29fde38e01b5))
* **words:** only check modes for `is_enabled` when needed ([80dcb88](https://github.com/folke/snacks.nvim/commit/80dcb88ede1a96f79edd3b7ede0bc41d51dd8a2d))
* **zen:** set zindex to 40, lower than hover (45). Closes [#345](https://github.com/folke/snacks.nvim/issues/345) ([05f4981](https://github.com/folke/snacks.nvim/commit/05f49814f3a2f3ecb83d9e72b7f8f2af40351aad))

## [2.11.0](https://github.com/folke/snacks.nvim/compare/v2.10.0...v2.11.0) (2024-12-15)


### Features

* **indent:** properly handle continuation indents. Closes [#286](https://github.com/folke/snacks.nvim/issues/286) ([f2bb7fa](https://github.com/folke/snacks.nvim/commit/f2bb7fa94e4b9b1fa7f84066bbedea8b3d9875e3))
* **input:** allow configuring position of prompt and icon ([d0cb707](https://github.com/folke/snacks.nvim/commit/d0cb7070e98d6a2ca31d94dd04d7048c9b258f33))
* **notifier:** notification `history` option ([#297](https://github.com/folke/snacks.nvim/issues/297)) ([8f56e19](https://github.com/folke/snacks.nvim/commit/8f56e19f916f8075e2bfb534d723e3d850e256a4))
* **scope:** `Scope:inner` for indent based and treesitter scopes ([8a8b1c9](https://github.com/folke/snacks.nvim/commit/8a8b1c976fc2736a3b91697750074fd3b23a24c9))
* **scope:** added `__tostring` for debugging ([94e0849](https://github.com/folke/snacks.nvim/commit/94e0849c3aae3b818cad2804c256c57318256c72))
* **scope:** added `opts.cursor` to take cursor column into account for scope detection. (defaults to true). Closes [#282](https://github.com/folke/snacks.nvim/issues/282) ([54bc6ba](https://github.com/folke/snacks.nvim/commit/54bc6bab2dbd07270c8c3fd447e8b72f825c315c))
* **scope:** text objects now use treesitter scopes by default. See [#231](https://github.com/folke/snacks.nvim/issues/231) ([a953697](https://github.com/folke/snacks.nvim/commit/a9536973a9111c3c7b66fb51bc5f62be27850884))
* **statuscolumn:** allow left/right to be a function. Closes [#288](https://github.com/folke/snacks.nvim/issues/288) ([cb42b95](https://github.com/folke/snacks.nvim/commit/cb42b952c5d4047f8e805c02c7aa596eb4e45ef2))
* **util:** on_key handler ([002d5eb](https://github.com/folke/snacks.nvim/commit/002d5eb5c2710a4e7456dd572543369e8424fd64))
* **win:** win:line() ([17494ad](https://github.com/folke/snacks.nvim/commit/17494ad9bf98e82c6a16f032cb3c9c82e072371a))


### Bug Fixes

* **dashboard:** telescope can't be run from a `vim.schedule` for some reason ([dcc5338](https://github.com/folke/snacks.nvim/commit/dcc5338e6f2a825b78791c96829d7e5a29e3ea5d))
* **indent:** `opts.indent.blank` now defaults to `listchars.space`. Closes [#291](https://github.com/folke/snacks.nvim/issues/291) ([31bc409](https://github.com/folke/snacks.nvim/commit/31bc409342b00d406963de3e1f38f3a2f84cfdcb))
* **indent:** fixup ([14d71c3](https://github.com/folke/snacks.nvim/commit/14d71c3fb2856634a8697f7c9f01704980e49bd0))
* **indent:** honor lead listchar ([#303](https://github.com/folke/snacks.nvim/issues/303)) ([7db0cc9](https://github.com/folke/snacks.nvim/commit/7db0cc9281b23c71155422433b6f485675674932))
* **indent:** honor listchars and list when blank is `nil`. Closes [#296](https://github.com/folke/snacks.nvim/issues/296) ([0e150f5](https://github.com/folke/snacks.nvim/commit/0e150f5510e381753ddd18f29facba14716d5669))
* **indent:** lower priorities of indent guides ([7f66818](https://github.com/folke/snacks.nvim/commit/7f668185ea810304cef5cb166a51665d4859124b))
* **input:** check if parent win still exists. Fixes [#287](https://github.com/folke/snacks.nvim/issues/287) ([db768a5](https://github.com/folke/snacks.nvim/commit/db768a5497301aad7fcddae2fe578cb320cc9ca2))
* **input:** go back to insert mode if input was started from insert mode. Fixes [#287](https://github.com/folke/snacks.nvim/issues/287) ([5d00e6d](https://github.com/folke/snacks.nvim/commit/5d00e6dec5686d7d2a6d97288287892d117d579b))
* **input:** missing padding if neither title nor icon positioned left ([#292](https://github.com/folke/snacks.nvim/issues/292)) ([97542a7](https://github.com/folke/snacks.nvim/commit/97542a7d9bfc7f242acbaa9851a62c649222fec8))
* **input:** open input window with `noautocmd=true` set. Fixes [#287](https://github.com/folke/snacks.nvim/issues/287) ([26b7d4c](https://github.com/folke/snacks.nvim/commit/26b7d4cbd9f803d9f759fc00d0dc4caa0141048b))
* **scope:** add `indent` to `__eq` ([be2779e](https://github.com/folke/snacks.nvim/commit/be2779e942bee0932e9c14ef4ed3e4002be861ce))
* **scope:** better treesitter scope edge detection ([b7355c1](https://github.com/folke/snacks.nvim/commit/b7355c16fb441e33be993ade74130464b62304cf))
* **scroll:** check mousescroll before spamming ([3d67bda](https://github.com/folke/snacks.nvim/commit/3d67bda1e29b8e8108dd74d611bf5c8b42883838))
* **util:** on_key compat with Neovim 0.9 ([effa885](https://github.com/folke/snacks.nvim/commit/effa885120670ca8a1775fc16ab2ec9e8040c288))

## [2.10.0](https://github.com/folke/snacks.nvim/compare/v2.9.0...v2.10.0) (2024-12-13)


### Features

* **animate:** add done to animation object ([ec73346](https://github.com/folke/snacks.nvim/commit/ec73346b7d4a25e440538141d5b8c68e42a1047d))
* **lazygit:** respect existing LG_CONFIG_FILE when setting config paths ([#208](https://github.com/folke/snacks.nvim/issues/208)) ([ef114c0](https://github.com/folke/snacks.nvim/commit/ef114c0efede3339221df5bc5b250aa9f8328b8d))
* **scroll:** added spamming detection and disable animations when user is spamming keys :) ([c58605f](https://github.com/folke/snacks.nvim/commit/c58605f8b3abf974e984ca5483cbe6ab9d2afc6e))
* **scroll:** improve smooth scrolling when user is spamming keys ([5532ba0](https://github.com/folke/snacks.nvim/commit/5532ba07be1306eb05c727a27368a8311bae3eeb))
* **zen:** added on_open / on_close callbacks ([5851de1](https://github.com/folke/snacks.nvim/commit/5851de157a08c96a0ca15580ced2ea53063fd65d))
* **zen:** make zen/zoom mode work for floating windows. Closes [#5028](https://github.com/folke/snacks.nvim/issues/5028) ([05bb957](https://github.com/folke/snacks.nvim/commit/05bb95739a362f8bec382f164f07c53137244627))


### Bug Fixes

* **dashboard:** set cursor to non-hidden actionable items. Fixes [#273](https://github.com/folke/snacks.nvim/issues/273) ([7c7b18f](https://github.com/folke/snacks.nvim/commit/7c7b18fdeeb7e228463b41d805cb47327f3d03f1))
* **indent:** fix rendering issues when `only_scope` is set for indent. Fixes [#268](https://github.com/folke/snacks.nvim/issues/268) ([370703d](https://github.com/folke/snacks.nvim/commit/370703da81a19db9d8bf41bb518e7b6959e53cea))
* **indent:** only render adjusted top/bottom. See [#268](https://github.com/folke/snacks.nvim/issues/268) ([54294cb](https://github.com/folke/snacks.nvim/commit/54294cba6a17ec048a63837fa341e6a663f3217d))
* **notifier:** set `modifiable=false` for notifier history ([12e68a3](https://github.com/folke/snacks.nvim/commit/12e68a33b5a1fd3648a7a558ef027fbb245125f7))
* **scope:** change from/to selection to make more sense ([e8dd394](https://github.com/folke/snacks.nvim/commit/e8dd394c01699276e8f7214957625222c30c8e9e))
* **scope:** possible loop? See [#278](https://github.com/folke/snacks.nvim/issues/278) ([ac6a748](https://github.com/folke/snacks.nvim/commit/ac6a74823b29cc1839df82fc839b81400ca80d45))
* **scratch:** normalize filename ([5200a8b](https://github.com/folke/snacks.nvim/commit/5200a8baa59a96e73786c11192282d2d3e10deeb))
* **scroll:** don't animate scroll distance 1 ([a986851](https://github.com/folke/snacks.nvim/commit/a986851a74512683c3331fa72a220751026fd611))

## [2.9.0](https://github.com/folke/snacks.nvim/compare/v2.8.0...v2.9.0) (2024-12-12)


### Features

* **animate:** allow disabling all animations globally or per buffer ([25c290d](https://github.com/folke/snacks.nvim/commit/25c290d7c093f0c57473ffcccf56780b6d58dd37))
* **animate:** allow toggling buffer-local / global animations with or without id ([50912dc](https://github.com/folke/snacks.nvim/commit/50912dc2fd926a49e3574d7029aed11fae3fb45b))
* **dashboard:** add dashboard startuptime icon option ([#214](https://github.com/folke/snacks.nvim/issues/214)) ([63506d5](https://github.com/folke/snacks.nvim/commit/63506d5168d2bb7679026cab80df1adfe3cd98b8))
* **indent:** animation styles `out`, `up_down`, `up`, `down` ([0a9b013](https://github.com/folke/snacks.nvim/commit/0a9b013ff13f6d1a550af2eac366c73d25e55e0a))
* **indent:** don't animate indents when new scope overlaps with the previous one, taking white-space into account. See [#264](https://github.com/folke/snacks.nvim/issues/264) ([9b4a859](https://github.com/folke/snacks.nvim/commit/9b4a85905aaa114e04a9371585953e96b3095f93))
* **indent:** move animate settings top-level, since they impact both scope and chunk ([baf8c18](https://github.com/folke/snacks.nvim/commit/baf8c180d9dda5797b4da538f7af122f4349f554))
* **toggle:** added zoom toggle ([3367705](https://github.com/folke/snacks.nvim/commit/336770581348c137bc2cb3967cc2af90b2ff51a2))
* **toggle:** return toggle after map ([4f22016](https://github.com/folke/snacks.nvim/commit/4f22016b4b765f3335ae7682fb5b3b79b414ecbd))
* **util:** get var either from buffer or global ([4243912](https://github.com/folke/snacks.nvim/commit/42439123c4fbc088fbe0bdd636a6bdc501794491))


### Bug Fixes

* **indent:** make sure cursor line is in scope for the `out` style. Fixes [#264](https://github.com/folke/snacks.nvim/issues/264) ([39c009f](https://github.com/folke/snacks.nvim/commit/39c009fe0b45243ccbbd372e659dcbd9409a68df))
* **indent:** when at edge of two blocks, prefer the one below. See [#231](https://github.com/folke/snacks.nvim/issues/231) ([2457d91](https://github.com/folke/snacks.nvim/commit/2457d913dc92835da12fc071b43bce3a03d31470))

## [2.8.0](https://github.com/folke/snacks.nvim/compare/v2.7.0...v2.8.0) (2024-12-11)


### Features

* **animate:** added animate plugin ([971229e](https://github.com/folke/snacks.nvim/commit/971229e8a93dab7dc73fe379110cdb47a7fd1387))
* **animate:** added animation context to callbacks ([1091280](https://github.com/folke/snacks.nvim/commit/109128087709fe5cba39e6983b8722b60cce8120))
* **dim:** added dim plugin ([4dda551](https://github.com/folke/snacks.nvim/commit/4dda5516e88a64c2b387727662d4ecd645582c55))
* **indent:** added indent plugin ([2c4021c](https://github.com/folke/snacks.nvim/commit/2c4021c4663ff4fe5da5b95c3e06a4f6eb416502))
* **indent:** allow disabling indent guides. See [#230](https://github.com/folke/snacks.nvim/issues/230) ([4a4ad63](https://github.com/folke/snacks.nvim/commit/4a4ad633dc9f864532716af4387b5e035d57768c))
* **indent:** allow disabling scope highlighting ([99207ee](https://github.com/folke/snacks.nvim/commit/99207ee44d3a2b4d14c915b08407bae708749235))
* **indent:** optional rendering of scopes as chunks. Closes [#230](https://github.com/folke/snacks.nvim/issues/230) ([109a0d2](https://github.com/folke/snacks.nvim/commit/109a0d207eeee49e13a6640131b44383e31d0b0f))
* **input:** added `input` snack ([70902ee](https://github.com/folke/snacks.nvim/commit/70902eee9e5aca7791450c6065dd51bed4651f24))
* **profiler:** on_close can now be a function ([48a5879](https://github.com/folke/snacks.nvim/commit/48a58792a0dd2e3c9249cfa4b1df73a8ea86a290))
* **scope:** added scope plugin ([63a279c](https://github.com/folke/snacks.nvim/commit/63a279c4e2e84ed02b5a2a6c2f84d68daf8f906a))
* **scope:** fill the range for treesitter scopes ([38ed01b](https://github.com/folke/snacks.nvim/commit/38ed01b5a229fc0c41b07dde08e9119de9ff1c4e))
* **scope:** text objects and jumping for scopes. Closes [#231](https://github.com/folke/snacks.nvim/issues/231) ([8faafb3](https://github.com/folke/snacks.nvim/commit/8faafb34831c48f3ff777d6bd0ced1c68c8ab82f))
* **scroll:** added smooth scrolling plugin ([38a5ccc](https://github.com/folke/snacks.nvim/commit/38a5ccc3a6436ba67fba71f6a2a9693ee1c2f142))
* **scroll:** allow disabling scroll globally or for some buffers ([04f15c1](https://github.com/folke/snacks.nvim/commit/04f15c1ba29afa6d1b085eb0d85a654c88be8fde))
* **scroll:** use `on_key` to track mouse scrolling ([26c3e49](https://github.com/folke/snacks.nvim/commit/26c3e4960f37320bcd418ec18f859b0e24d1e7d8))
* **scroll:** user virtual columns while scrolling ([fefa6fd](https://github.com/folke/snacks.nvim/commit/fefa6fd6920a2f8a6e717ae856c14e32d5d76ddb))
* **snacks:** zen mode ([c509ea5](https://github.com/folke/snacks.nvim/commit/c509ea52b7b3487e3d904d9f3d55d20ad136facb))
* **toggle:** add which-key mappings when which-key loads ([c9f494b](https://github.com/folke/snacks.nvim/commit/c9f494bd9a4729722186d2631ca91192ffc19b40))
* **toggle:** add zen mode toggle ([#243](https://github.com/folke/snacks.nvim/issues/243)) ([9454ba3](https://github.com/folke/snacks.nvim/commit/9454ba35f8c6ad3baeda4132fe1e5c96a5850960))
* **toggle:** added toggle for smooth scroll ([aeec09c](https://github.com/folke/snacks.nvim/commit/aeec09c5413c87df7ca827bd6b7c3fbf0f4d2909))
* **toggle:** toggles for new plugins ([bddae83](https://github.com/folke/snacks.nvim/commit/bddae83141d9e18b23a5d7a9ccc52c76ad736ca2))
* **util:** added Snacks.util.on_module to execute a callback when a module loads (or immediately when already loaded) ([f540b7b](https://github.com/folke/snacks.nvim/commit/f540b7b6cc10223adcbd6d9747155a076ddfa9a4))
* **util:** set_hl no longer sets default=true when not specified ([d6309c6](https://github.com/folke/snacks.nvim/commit/d6309c62b8e5910407449975b9e333c2699d06d0))
* **win:** added actions to easily combine actions in keymaps ([46362a5](https://github.com/folke/snacks.nvim/commit/46362a5a9c2583094bd0416dd6dea17996eaecf9))
* **win:** allow configuring initial text to display in the buffer ([003ea8d](https://github.com/folke/snacks.nvim/commit/003ea8d6edcf6d813bfdc143ffe4fa6cc55c0ea5))
* **win:** allow customizing backdrop window ([cdb495c](https://github.com/folke/snacks.nvim/commit/cdb495cb8f7b801d9d731cdfa2c6f92fadf1317d))
* **win:** col/row can be negative calculated on height/end of parent ([bd49d2f](https://github.com/folke/snacks.nvim/commit/bd49d2f32e567cbe42adf0bd8582b7829de6c1dc))
* **words:** added toggle for words ([bd7cf03](https://github.com/folke/snacks.nvim/commit/bd7cf038234a84b48d1c1f09dffae9e64910ff7e))
* **zen:** `zz` when entering zen mode ([b5cb90f](https://github.com/folke/snacks.nvim/commit/b5cb90f91dedaa692c4da1dfa216d13e58ad219d))
* **zen:** added zen plugin ([afb89ea](https://github.com/folke/snacks.nvim/commit/afb89ea159a20e1241656af5aa46f638327d2f5a))
* **zen:** added zoom indicator ([8459e2a](https://github.com/folke/snacks.nvim/commit/8459e2adc090aaf59865a60836c360744d82ed0a))


### Bug Fixes

* **compat:** fixes for Neovim &lt; 0.10 ([33fbb30](https://github.com/folke/snacks.nvim/commit/33fbb309f8c21c8ec30b99fe323a5cc55c84c5bc))
* **dashboard:** add filetype to terminal sections ([#215](https://github.com/folke/snacks.nvim/issues/215)) ([9c68a54](https://github.com/folke/snacks.nvim/commit/9c68a54af652ff69348848dad62c4cd901da59a0))
* **dashboard:** don't open with startup option args ([#222](https://github.com/folke/snacks.nvim/issues/222)) ([6b78172](https://github.com/folke/snacks.nvim/commit/6b78172864ef94cd5f2ab184c0f98cf36f5a8e74))
* **dashboard:** override foldmethod ([47ad2a7](https://github.com/folke/snacks.nvim/commit/47ad2a7bfa49c3eb5c20083de82a39f59fb8f17a))
* **debug:** schedule wrap print ([3a107af](https://github.com/folke/snacks.nvim/commit/3a107afbf8dffabf6c2754750c51d740707b76af))
* **dim:** check if win still exist when animating. Closes [#259](https://github.com/folke/snacks.nvim/issues/259) ([69018d0](https://github.com/folke/snacks.nvim/commit/69018d070c9a0db76abc0f34539287e1c181a5d4))
* **health:** health checks ([72eba84](https://github.com/folke/snacks.nvim/commit/72eba841801928b00a1f1f74e1f976a31534a674))
* **indent:** always align indents with shiftwidth ([1de6c15](https://github.com/folke/snacks.nvim/commit/1de6c152883b576524201a465e1b8a09622a6041))
* **indent:** always render underline regardless of leftcol ([4e96e69](https://github.com/folke/snacks.nvim/commit/4e96e692e8a3c6c67f9c9b2971b6fa263461054b))
* **indent:** always use scope hl to render underlines. Fixes [#234](https://github.com/folke/snacks.nvim/issues/234) ([8723945](https://github.com/folke/snacks.nvim/commit/8723945183aac31671d1fa27481c90dc7c665c02))
* **indent:** better way of dealing with indents on blank lines. See [#246](https://github.com/folke/snacks.nvim/issues/246) ([c129683](https://github.com/folke/snacks.nvim/commit/c1296836f5c36e75b508aae9a76aa0931058feec))
* **indent:** expand scopes to inlude end_pos based on the end_pos scope. See [#231](https://github.com/folke/snacks.nvim/issues/231) ([897f801](https://github.com/folke/snacks.nvim/commit/897f8019248009eca191185cf7094e04c9371a85))
* **indent:** gradually increase scope when identical to visual selection for text objects ([bc7f96b](https://github.com/folke/snacks.nvim/commit/bc7f96bdee77368d4ddae2613823f085266529ab))
* **indent:** properly deal with empty lines when highlighting scopes. Fixes [#246](https://github.com/folke/snacks.nvim/issues/246). Fixes [#245](https://github.com/folke/snacks.nvim/issues/245) ([d04cf1d](https://github.com/folke/snacks.nvim/commit/d04cf1dc4f332bade99c300283380bf0893f1996))
* **indent:** set max_size=1 for textobjects and jumps by default. See [#231](https://github.com/folke/snacks.nvim/issues/231) ([5f217bc](https://github.com/folke/snacks.nvim/commit/5f217bca6adc88a5dc6aa55e5bf0580b95025a52))
* **indent:** set shiftwidth to tabstop when 0 ([782b6ee](https://github.com/folke/snacks.nvim/commit/782b6ee3fca35ede62b8dba866a9ad5c50edfdce))
* **indent:** underline. See [#234](https://github.com/folke/snacks.nvim/issues/234) ([51f9569](https://github.com/folke/snacks.nvim/commit/51f95693aedcde10e65c8121c6fd1293a3ac3819))
* **indent:** use correct config options ([5352198](https://github.com/folke/snacks.nvim/commit/5352198b5a59968c871b962fa15f1d7ca4eb7b52))
* **init:** enabled check ([519a45b](https://github.com/folke/snacks.nvim/commit/519a45bfe5df7fdf5aea0323e978e20eb52e15bc))
* **init:** set input disabled by default. Fixes [#227](https://github.com/folke/snacks.nvim/issues/227) ([e9d0993](https://github.com/folke/snacks.nvim/commit/e9d099322fca1bb7b35e781230e4a7478ded86bf))
* **input:** health check. Fixes [#239](https://github.com/folke/snacks.nvim/issues/239) ([acf743f](https://github.com/folke/snacks.nvim/commit/acf743fcfc4e0e42e1c9fe5c06f677849fa38e8b))
* **input:** set current win before executing callback. Fixes [#257](https://github.com/folke/snacks.nvim/issues/257) ([c17c1b2](https://github.com/folke/snacks.nvim/commit/c17c1b2f6c99f0ed4f3ab8f00bf32bb39f9d0186))
* **input:** set current win in `vim.schedule` so that it works properly from `expr` keymaps. Fixes [#257](https://github.com/folke/snacks.nvim/issues/257) ([8c2410c](https://github.com/folke/snacks.nvim/commit/8c2410c2de0a86c095177a831993f8eea78a63b6))
* **input:** update window position in the context of the parent window to make sure position=cursor works as expected. Fixes [#254](https://github.com/folke/snacks.nvim/issues/254) ([6c27ff2](https://github.com/folke/snacks.nvim/commit/6c27ff2a365c961831c7620365dd87fa8d8ad633))
* **input:** various minor visual fixes ([#252](https://github.com/folke/snacks.nvim/issues/252)) ([e01668c](https://github.com/folke/snacks.nvim/commit/e01668c36771c0c1424a2ce3ab26a09cbb43d472))
* **notifier:** toggle show history. Fixes [#197](https://github.com/folke/snacks.nvim/issues/197) ([8b58b55](https://github.com/folke/snacks.nvim/commit/8b58b55e40221ca5124f156f47e46185310fbe1c))
* **scope:** better edge detection for treesitter scopes ([6b02a09](https://github.com/folke/snacks.nvim/commit/6b02a09e5e81e4e38a42e0fcc2d7f0350404c228))
* **scope:** return `nil` when buffer is empty for indent scope ([4aa378a](https://github.com/folke/snacks.nvim/commit/4aa378a35e8f3d3771410344525cc4bc9ac50e8a))
* **scope:** take edges into account for min_size ([e2e6c86](https://github.com/folke/snacks.nvim/commit/e2e6c86d214029bfeae5d50929aee72f7059b7b7))
* **scope:** typo for textobject ([0324125](https://github.com/folke/snacks.nvim/commit/0324125ca1e5a5e6810d28ea81bb2c7c0af1dc16))
* **scroll:** better toggle ([3dcaad8](https://github.com/folke/snacks.nvim/commit/3dcaad8d0aacc1a736f75fee5719adbf80cbbfa2))
* **scroll:** disable scroll by default for terminals ([7b5a78a](https://github.com/folke/snacks.nvim/commit/7b5a78a5c76cdf2c73abbeef47ac14bb8ccbee72))
* **scroll:** don't animate invalid windows ([41ca13d](https://github.com/folke/snacks.nvim/commit/41ca13d119b328872ed1da9c8f458c5c24962d31))
* **scroll:** don't bother setting cursor when scrolloff is larger than half of viewport. Fixes [#240](https://github.com/folke/snacks.nvim/issues/240) ([0ca9ca7](https://github.com/folke/snacks.nvim/commit/0ca9ca79926b3bf473172eee7072fa2838509fba))
* **scroll:** move scrollbind check to M.check ([7211ec0](https://github.com/folke/snacks.nvim/commit/7211ec08ce01da754544f66e965effb13fd22fd3))
* **scroll:** only animate the current window when scrollbind is active ([c9880ce](https://github.com/folke/snacks.nvim/commit/c9880ce872ca000d17ae8d62b10e913045f54735))
* **scroll:** set cursor to correct position when target is reached. Fixes [#236](https://github.com/folke/snacks.nvim/issues/236) ([4209929](https://github.com/folke/snacks.nvim/commit/4209929e6d4f67d3d216d1ab5f52dc387c8e27c2))
* **scroll:** use actual scrolling to perform the scroll to properly deal with folds etc. Fixes [#236](https://github.com/folke/snacks.nvim/issues/236) ([280a09e](https://github.com/folke/snacks.nvim/commit/280a09e4eef08157eface8398295eb7fa3f9a08d))
* **win:** ensure win is set when relative=win ([5d472b8](https://github.com/folke/snacks.nvim/commit/5d472b833b7f925033fea164de0ab9e389e31bef))
* **words:** incorrect enabled check. Fixes [#247](https://github.com/folke/snacks.nvim/issues/247) ([9c8f3d5](https://github.com/folke/snacks.nvim/commit/9c8f3d531874ebd20eebe259f5c30cea575a1bba))
* **zen:** properly close existing zen window on toggle ([14da56e](https://github.com/folke/snacks.nvim/commit/14da56ee9791143ef2503816fb93f8bd2bf0b58d))
* **zen:** return after closing. Fixes [#259](https://github.com/folke/snacks.nvim/issues/259) ([b13eaf6](https://github.com/folke/snacks.nvim/commit/b13eaf6bd9089d8832c79f4088e72affc449c8ee))
* **zen:** when Normal is transparent, show an opaque transparent backdrop. Fixes [#235](https://github.com/folke/snacks.nvim/issues/235) ([d93de7a](https://github.com/folke/snacks.nvim/commit/d93de7af6916d2c734c9420624b8703236f386ff))


### Performance Improvements

* **animate:** check for animation easing updates ouside the main loop and schedule an update when needed ([03c0774](https://github.com/folke/snacks.nvim/commit/03c0774e8555a38267624309d4f00a30e351c4be))
* **input:** lazy-load `vim.ui.input` ([614df63](https://github.com/folke/snacks.nvim/commit/614df63acfb5ce9b1ac174ea4f09e545a086af4d))
* **util:** redraw helpers ([9fb88c6](https://github.com/folke/snacks.nvim/commit/9fb88c67b60cbd9d4a56f9aadcb9285929118518))

## [2.7.0](https://github.com/folke/snacks.nvim/compare/v2.6.0...v2.7.0) (2024-12-07)


### Features

* **bigfile:** disable matchparen, set foldmethod=manual, set conceallevel=0 ([891648a](https://github.com/folke/snacks.nvim/commit/891648a483b6f5410ec9c8b74890d5a00b50fa4c))
* **dashbard:** explude files from stdpath data/cache/state in recent files and projects ([b99bc64](https://github.com/folke/snacks.nvim/commit/b99bc64ef910cd075e4ab9cf0914e99e1a1d61c1))
* **dashboard:** allow items to be hidden, but still create the keymaps etc ([7a47eb7](https://github.com/folke/snacks.nvim/commit/7a47eb76df2fd36bfcf3ed5c4da871542e1386be))
* **dashboard:** allow terminal sections to have actions. Closes [#189](https://github.com/folke/snacks.nvim/issues/189) ([78f44f7](https://github.com/folke/snacks.nvim/commit/78f44f720b1b0609930581965f4f92649efae95b))
* **dashboard:** hide title if section has no items. Fixes [#184](https://github.com/folke/snacks.nvim/issues/184) ([d370be6](https://github.com/folke/snacks.nvim/commit/d370be6d6966a298725901abad4bec90264859af))
* **dashboard:** make buffer not listed ([#191](https://github.com/folke/snacks.nvim/issues/191)) ([42d6277](https://github.com/folke/snacks.nvim/commit/42d62775d82b7af4dbe001b04be6a8a6e461e8ec))
* **dashboard:** when a section has a title, use that for action and key. If not put it in the section. Fixes [#189](https://github.com/folke/snacks.nvim/issues/189) ([045a17d](https://github.com/folke/snacks.nvim/commit/045a17da069aae6221b2b3eae8610c2aa5ca03ea))
* **debug:** added `Snacks.debug.run()` to execute the buffer or selection with inlined print and errors ([e1fe4f5](https://github.com/folke/snacks.nvim/commit/e1fe4f5afed5c679fd2eed3486f17e8c0994b982))
* **gitbrowse:** added `line_count`. See [#186](https://github.com/folke/snacks.nvim/issues/186) ([f03727c](https://github.com/folke/snacks.nvim/commit/f03727c77f739503fd297dd12a826c2aca3490f9))
* **gitbrowse:** opts.notify ([a856952](https://github.com/folke/snacks.nvim/commit/a856952ab24757f4eaf4ae2e1728d097f1866681))
* **gitbrowse:** url pattern can now also be a function ([0a48c2e](https://github.com/folke/snacks.nvim/commit/0a48c2e726e6ca90370260a05618f45345dbb66a))
* **notifier:** reverse notif history by default for `show_history` ([5a50738](https://github.com/folke/snacks.nvim/commit/5a50738b8e952519658570f31ff5f24e06882f18))
* **scratch:** `opts.ft` can now be a function and defaults to the ft of the current buffer or markdown ([652303e](https://github.com/folke/snacks.nvim/commit/652303e6de5fa746709979425f4bed763e3fcbfa))
* **scratch:** change keymap to execute buffer/selection to `&lt;cr&gt;` ([7db0ed4](https://github.com/folke/snacks.nvim/commit/7db0ed4239a2f67c0ca288aaac21bc6aa65212a7))
* **scratch:** use `Snacks.debug.run()` to execute buffer/selection ([32c46b4](https://github.com/folke/snacks.nvim/commit/32c46b4e2f61c026e41b3fa128d01b0e89da106c))
* **snacks:** added `Snacks.profiler` ([8088799](https://github.com/folke/snacks.nvim/commit/808879951f960399844c89efef9aec1724f83402))
* **snacks:** added new `scratch` snack ([1cec695](https://github.com/folke/snacks.nvim/commit/1cec695fefb6e42ee644cfaf282612c213009aed))
* **toggle:** toggles for the profiler ([999ae07](https://github.com/folke/snacks.nvim/commit/999ae07808858df08d30eb099a8dbce401527008))
* **util:** encode/decode a string to be used as a filename ([e6f6397](https://github.com/folke/snacks.nvim/commit/e6f63970de2225ad44ed08af7ffd8a0f37d8fc58))
* **util:** simple function to get an icon ([7c29848](https://github.com/folke/snacks.nvim/commit/7c29848e89861b40e751cc15c557cf1e574acf66))
* **win:** added `opts.fixbuf` to configure fixed window buffers ([1f74d1c](https://github.com/folke/snacks.nvim/commit/1f74d1ce77d2015e2802027c93b9e0bcd548e4d1))
* **win:** backdrop can now be made opaque ([681b9c9](https://github.com/folke/snacks.nvim/commit/681b9c9d650e7b01a5e54567656f646fbd3b8d46))
* **win:** width/height can now be a function ([964d7ae](https://github.com/folke/snacks.nvim/commit/964d7ae99af1f45949175e1494562a796e2ef99b))


### Bug Fixes

* **dashboard:** calculate proper offset when item has no text ([6e3b954](https://github.com/folke/snacks.nvim/commit/6e3b9546de4871a696652cfcee6768c39e7b8ee9))
* **dashboard:** prevent possible duplicate recent files. Fixes [#171](https://github.com/folke/snacks.nvim/issues/171) ([93b254d](https://github.com/folke/snacks.nvim/commit/93b254d65845aa44ad1e01000c26e1faf5efb9a6))
* **dashboard:** take hidden items into account when calculating padding. Fixes [#194](https://github.com/folke/snacks.nvim/issues/194) ([736ce44](https://github.com/folke/snacks.nvim/commit/736ce447e8815eb231271abf7d49d8fa7d96e225))
* **dashboard:** take indent into account when calculating terminal width ([cda695e](https://github.com/folke/snacks.nvim/commit/cda695e53ffb34c7569dc3536134c9e432b2a1c1))
* **dashboard:** truncate file names when too long. Fixes [#183](https://github.com/folke/snacks.nvim/issues/183) ([4bdf7da](https://github.com/folke/snacks.nvim/commit/4bdf7daece384ab8a5472e6effd5fd6167a5ce6a))
* **debug:** better way of getting visual selection. See [#190](https://github.com/folke/snacks.nvim/issues/190) ([af41cb0](https://github.com/folke/snacks.nvim/commit/af41cb088d3ff8da9dede9fbdd5c81860bc37e64))
* **gitbrowse:** opts.notify ([2436557](https://github.com/folke/snacks.nvim/commit/243655796e4adddf58ce581f1b86a283130ecf41))
* **gitbrowse:** removed debug ([f894952](https://github.com/folke/snacks.nvim/commit/f8949523ed3f27f976e5346051a6658957d9492a))
* **gitbrowse:** use line_start and line_end directly in patterns. Closes [#186](https://github.com/folke/snacks.nvim/issues/186) ([adf0433](https://github.com/folke/snacks.nvim/commit/adf0433e8fca3fbc7287ac7b05f01f10ac354283))
* **profiler:** startup opts ([85f5132](https://github.com/folke/snacks.nvim/commit/85f51320b2662830a6435563668a04ab21686178))
* **scratch:** always set filetype on the buffer. Fixes [#179](https://github.com/folke/snacks.nvim/issues/179) ([6db50cf](https://github.com/folke/snacks.nvim/commit/6db50cfe2d1b333512e8175d072a2f82e796433d))
* **scratch:** floating window title/footer hl groups ([6c25ab1](https://github.com/folke/snacks.nvim/commit/6c25ab1108d12ef3642e97e3757710e69782cbd1))
* **scratch:** make sure win.opts.keys exists. See [#190](https://github.com/folke/snacks.nvim/issues/190) ([50bd510](https://github.com/folke/snacks.nvim/commit/50bd5103ba0a15294b1a931fda14900e7fd10161))
* **scratch:** sort keys. Fixes [#193](https://github.com/folke/snacks.nvim/issues/193) ([0df7a08](https://github.com/folke/snacks.nvim/commit/0df7a08b01b037e434efe7cd25e7d4608a282a92))
* **scratch:** weirdness with visual selection and inclusive/exclusive. See [#190](https://github.com/folke/snacks.nvim/issues/190) ([f955f08](https://github.com/folke/snacks.nvim/commit/f955f082e09683d02df3fd0f8b621b938f38e6aa))
* **statuscolumn:** add virtnum and relnum to cache key. See [#198](https://github.com/folke/snacks.nvim/issues/198) ([3647ca7](https://github.com/folke/snacks.nvim/commit/3647ca7d8a47362a01b539f5b6efc2d5339b5e8e))
* **statuscolumn:** don't show signs on virtual ligns. See [#198](https://github.com/folke/snacks.nvim/issues/198) ([f5fb59c](https://github.com/folke/snacks.nvim/commit/f5fb59cc4c62e25745bbefd2ef55665a67196245))
* **util:** better support for nvim-web-devicons ([ddaa2aa](https://github.com/folke/snacks.nvim/commit/ddaa2aaba59bbd05c03992bfb295c98ccd3b3e50))
* **util:** make sure to always return an icon ([ca7188c](https://github.com/folke/snacks.nvim/commit/ca7188c531350fe313c211ad60a59d642749f93e))
* **win:** allow resolving nil window option values. Fixes [#179](https://github.com/folke/snacks.nvim/issues/179) ([0043fa9](https://github.com/folke/snacks.nvim/commit/0043fa9ee142b63ab653507f2e6f45395e8a23d5))
* **win:** don't force close modified buffers ([d517b11](https://github.com/folke/snacks.nvim/commit/d517b11cabf94bf833d020c7a0781122d0f48c06))
* **win:** update opts.wo for padding instead of vim.wo directly ([446f502](https://github.com/folke/snacks.nvim/commit/446f50208fe823787ce60a8b216a622a4b6b63dd))
* **win:** update window local options when the buffer changes ([630d96c](https://github.com/folke/snacks.nvim/commit/630d96cf1f0403352580f2d119fc3b3ba29e33a4))


### Performance Improvements

* **dashboard:** properly cleanup autocmds ([8e6d977](https://github.com/folke/snacks.nvim/commit/8e6d977ec985a1b3f12a53741df82881a7835f9a))
* **statuscolumn:** optimize caching ([d972bc0](https://github.com/folke/snacks.nvim/commit/d972bc0a471fbf3067a115924a4add852d15f5f0))

## [2.6.0](https://github.com/folke/snacks.nvim/compare/v2.5.0...v2.6.0) (2024-11-29)


### Features

* **config:** allow overriding resolved options for a plugin. See [#164](https://github.com/folke/snacks.nvim/issues/164) ([d730a13](https://github.com/folke/snacks.nvim/commit/d730a13b5519fa901114cbdd0b2d484067068cce))
* **config:** make it easier to use examples in your config ([6e3cb7e](https://github.com/folke/snacks.nvim/commit/6e3cb7e53c0a1b314203d392dc1b7df8207a31a6))
* **dashboard:** allow passing win=0, buf=0 to use for the dashboard instead of creating a new window ([417e07c](https://github.com/folke/snacks.nvim/commit/417e07c0d22173a0a50ed8207e913ba25b96088e))
* **dashboard:** always render cache even when expired. Then refresh when needed. ([59f8f0d](https://github.com/folke/snacks.nvim/commit/59f8f0db99e7a2d4f6a181f02f3fe77355c016c8))
* **gitbrowse:** add Bitbucket URL patterns ([#163](https://github.com/folke/snacks.nvim/issues/163)) ([53441c9](https://github.com/folke/snacks.nvim/commit/53441c97030dbc15b4a22d56e33054749a13750f))
* **gitbrowse:** open commit when word is valid hash ([#161](https://github.com/folke/snacks.nvim/issues/161)) ([59c8eb3](https://github.com/folke/snacks.nvim/commit/59c8eb36ae6933dd54d87811fec22decfe4f303c))
* **health:** check that snacks.nvim plugin spec is correctly setup ([2c7b4b7](https://github.com/folke/snacks.nvim/commit/2c7b4b7971c8b488cfc9949f402f6c0307e24fce))
* **notifier:** added history opts.reverse ([bebd7e7](https://github.com/folke/snacks.nvim/commit/bebd7e70cdd336dcc582227c2f3bd6ea0cef60d9))
* **win:** go back to the previous window, when closing a snacks window ([51996df](https://github.com/folke/snacks.nvim/commit/51996dfeac5f0936aa1196e90b28760eb028ac1a))


### Bug Fixes

* **config:** check correct var for single config result. Fixes [#167](https://github.com/folke/snacks.nvim/issues/167) ([45fd0ef](https://github.com/folke/snacks.nvim/commit/45fd0efe41a453f1fa54a0892d352b931d6f88bb))
* **dashboard:** fixed mini.sessions.read. Fixes [#144](https://github.com/folke/snacks.nvim/issues/144) ([4e04b70](https://github.com/folke/snacks.nvim/commit/4e04b70ea3f6f91ae47e0fc7671e53e801171290))
* **dashboard:** terminal commands get 5 seconds to complete to trigger caching ([f83a7b0](https://github.com/folke/snacks.nvim/commit/f83a7b0ffb13adfae55a464f4d99fe3d4b578fe6))
* **git:** make git.get_root work for work-trees and cache git root checks. Closes [#136](https://github.com/folke/snacks.nvim/issues/136). Fixes [#115](https://github.com/folke/snacks.nvim/issues/115) ([9462273](https://github.com/folke/snacks.nvim/commit/9462273bf7c0e627da0f412c02daee907947078d))
* **init:** use rawget when loading modules to prevent possible recursive loading with invalid module fields ([d0794dc](https://github.com/folke/snacks.nvim/commit/d0794dcf8e988cf70c8db705a6e65867ba3b6e30))
* **notifier:** always show notifs directly when blocking ([0c7f7c5](https://github.com/folke/snacks.nvim/commit/0c7f7c5970d204d62488a4e351f1f1514a2a42e5))
* **notifier:** gracefully handle E565 errors ([0bbc9e7](https://github.com/folke/snacks.nvim/commit/0bbc9e7ae65820bc5ee356e1321656a7106d409a))
* **statuscolumn:** bad copy/paste!! Fixes [#152](https://github.com/folke/snacks.nvim/issues/152) ([7564a30](https://github.com/folke/snacks.nvim/commit/7564a30cad803c01f8ecc15683a280d2f0e9bdb7))
* **statuscolumn:** never error (in case of E565 for example). Fixes [#150](https://github.com/folke/snacks.nvim/issues/150) ([cf84008](https://github.com/folke/snacks.nvim/commit/cf840087c5adf1c076b61fdd044ac960b31e4e1e))
* **win:** handle E565 errors on close ([0b02044](https://github.com/folke/snacks.nvim/commit/0b020449ad8496c6bfd34e10bc69f807b52970f8))


### Performance Improvements

* **statuscolumn:** some small optims ([985be4a](https://github.com/folke/snacks.nvim/commit/985be4a759f6fe83e569679da431eeb7d2db5286))

## [2.5.0](https://github.com/folke/snacks.nvim/compare/v2.4.0...v2.5.0) (2024-11-22)


### Features

* **dashboard:** added Snacks.dashboard.update(). Closes [#121](https://github.com/folke/snacks.nvim/issues/121) ([c770ebe](https://github.com/folke/snacks.nvim/commit/c770ebeaf7b19abad8a447ef55b48cec71e7db54))
* **debug:** profile title ([0177079](https://github.com/folke/snacks.nvim/commit/017707955f465335900c4fd483c32df018fd3427))
* **notifier:** show indicator when notif has more lines. Closes [#112](https://github.com/folke/snacks.nvim/issues/112) ([cf72c06](https://github.com/folke/snacks.nvim/commit/cf72c06ee61f3102bf828ee7e8dde20316310374))
* **terminal:** added Snacks.terminal.get(). Closes [#122](https://github.com/folke/snacks.nvim/issues/122) ([7f63d4f](https://github.com/folke/snacks.nvim/commit/7f63d4fefb7ba22f6e98986f7adeb04f9f9369b1))
* **util:** get hl color ([b0da066](https://github.com/folke/snacks.nvim/commit/b0da066536493b6ed977744e4ee91fac01fcc2a8))
* **util:** set_hl managed ([9642695](https://github.com/folke/snacks.nvim/commit/96426953a029b12d02ad45849e086c1ee14e065b))


### Bug Fixes

* **dashboard:** `vim.pesc` for auto keys. Fixes [#134](https://github.com/folke/snacks.nvim/issues/134) ([aebffe5](https://github.com/folke/snacks.nvim/commit/aebffe535b09237b28d2c61bb3febab12bc95ae8))
* **dashboard:** align should always set width even if no alignment is needed. Fixes [#137](https://github.com/folke/snacks.nvim/issues/137) ([54d521c](https://github.com/folke/snacks.nvim/commit/54d521cd0fde5e3ccf36716f23371707d0267768))
* **dashboard:** better git check for advanced example. See [#126](https://github.com/folke/snacks.nvim/issues/126) ([b4a293a](https://github.com/folke/snacks.nvim/commit/b4a293aac747fbde7aafa72242a2d26dc17e325d))
* **dashboard:** open fullscreen on relaunch ([853240b](https://github.com/folke/snacks.nvim/commit/853240bb207ed7a2366c6c63ffc38f3b26fd484f))
* **dashboard:** randomseed needs argument on stable ([c359164](https://github.com/folke/snacks.nvim/commit/c359164872e82646e11c652fb0fbe723e58bfdd8))
* **debug:** include `main` in caller ([33d31af](https://github.com/folke/snacks.nvim/commit/33d31af1501ec154dba6008064d17ab72ec37d00))
* **git:** get_root should work for non file buffers ([723d8ea](https://github.com/folke/snacks.nvim/commit/723d8eac849749e9015d9e9598f99974684ca3bb))
* **notifier:** hide existing nofif if higher prio notif arrives and no free space for lower notif ([7a061de](https://github.com/folke/snacks.nvim/commit/7a061de75f758db23cf2c2ee0822a76356b54035))
* **quickfile:** don't load when bigfile detected. Fixes [#116](https://github.com/folke/snacks.nvim/issues/116) ([978424c](https://github.com/folke/snacks.nvim/commit/978424ce280ec85e78e9660b200aee9aa12e9ef2))
* **sessions:** change persisted.nvim load session command ([#118](https://github.com/folke/snacks.nvim/issues/118)) ([26bec4b](https://github.com/folke/snacks.nvim/commit/26bec4b51d617cd275218e9935fdff5390c18a87))
* **terminal:** hide on `q` instead of close ([30a0721](https://github.com/folke/snacks.nvim/commit/30a0721d56993a7125a247a07116f1a07e0efda4))

## [2.4.0](https://github.com/folke/snacks.nvim/compare/v2.3.0...v2.4.0) (2024-11-19)


### Features

* **dashboard:** hide tabline and statusline when loading during startup ([75dc74c](https://github.com/folke/snacks.nvim/commit/75dc74c5dc933b81cde85e8bc368a384343af69f))
* **dashboard:** when an item is wider than pane width and only one pane, then center it. See [#108](https://github.com/folke/snacks.nvim/issues/108) ([c15953e](https://github.com/folke/snacks.nvim/commit/c15953ee885cf8afb40dcd478569d7de2edae939))
* **gitbrowse:** open also visual selection range ([#89](https://github.com/folke/snacks.nvim/issues/89)) ([c29c0d4](https://github.com/folke/snacks.nvim/commit/c29c0d48500cb976c9210bb2d42909ad203cd4aa))
* **win:** detect alien buffers opening in managed windows and open them somewhere else. Fixes [#110](https://github.com/folke/snacks.nvim/issues/110) ([9c0d2e2](https://github.com/folke/snacks.nvim/commit/9c0d2e2e93615e70627e5c09c7bbb04e93eab2c6))


### Bug Fixes

* **dashboard:** always hide cursor ([68fcc25](https://github.com/folke/snacks.nvim/commit/68fcc258023404a0a0341a7cc93db47cd17f85f4))
* **dashboard:** check session managers in order ([1acea8b](https://github.com/folke/snacks.nvim/commit/1acea8b94005620dad70dfde6a6344c130a57c59))
* **dashboard:** fix race condition when sending data while closing ([4188446](https://github.com/folke/snacks.nvim/commit/4188446f86b5c6abae090eb6abca65d5d9bb8003))
* **dashboard:** minimum one pane even when it doesn't fit the screen. Fixes [#104](https://github.com/folke/snacks.nvim/issues/104) ([be8feef](https://github.com/folke/snacks.nvim/commit/be8feef4ab584f50aaa96b69d50b3f86a35aacff))
* **dashboard:** only check for piped stdin when in TUI. Ignore GUIs ([3311d75](https://github.com/folke/snacks.nvim/commit/3311d75f893191772a1b9525b18b94d8c3a8943a))
* **dashboard:** remove weird preset.keys function override. Just copy defaults if you want to change them ([0b9e09c](https://github.com/folke/snacks.nvim/commit/0b9e09cbd97c178ebe5db78fd373448448c5511b))

## [2.3.0](https://github.com/folke/snacks.nvim/compare/v2.2.0...v2.3.0) (2024-11-18)


### Features

* added dashboard health checks ([deb00d0](https://github.com/folke/snacks.nvim/commit/deb00d0ddc57d77f5f6c3e5510ba7c2f07e593eb))
* **dashboard:** added support for mini.sessions ([c8e209e](https://github.com/folke/snacks.nvim/commit/c8e209e6be9e8d8cdee19842a99ae7b89ac4248d))
* **dashboard:** allow opts.preset.keys to be a function with default keymaps as arg ([b7775ec](https://github.com/folke/snacks.nvim/commit/b7775ec879e14362d8e4082b7ed97a752bbb654a))
* **dashboard:** automatically detect streaming commands and don't cache those. tty-clock, cmatrix galore. Fixes [#100](https://github.com/folke/snacks.nvim/issues/100) ([082beb5](https://github.com/folke/snacks.nvim/commit/082beb508ccf3584aebfee845c1271d9f8b8abb6))
* **notifier:** timeout=0 keeps the notif visible till manually hidden. Closes [#102](https://github.com/folke/snacks.nvim/issues/102) ([0cf22a8](https://github.com/folke/snacks.nvim/commit/0cf22a8d87f28759c083969d67b55498e568a1b7))


### Bug Fixes

* **dashboard:** check uis for headless and stdin_tty. Fixes [#97](https://github.com/folke/snacks.nvim/issues/97). Fixes [#98](https://github.com/folke/snacks.nvim/issues/98) ([4ff08f1](https://github.com/folke/snacks.nvim/commit/4ff08f1c4d7b7b5d3e1da3b2cc9d6c341cd4dc1a))
* **dashboard:** debug output ([c0129da](https://github.com/folke/snacks.nvim/commit/c0129da4f839fd4306627b087cb722ea54c50c18))
* **dashboard:** disable `vim.wo.colorcolumn` ([#101](https://github.com/folke/snacks.nvim/issues/101)) ([43b4abb](https://github.com/folke/snacks.nvim/commit/43b4abb9f11a07d7130b461f9bd96b3e4e3c5b94))
* **dashboard:** notify on errors. Fixes [#99](https://github.com/folke/snacks.nvim/issues/99) ([2ae4108](https://github.com/folke/snacks.nvim/commit/2ae410889cbe6f59fb52f40cb86b25d6f7e874e2))
* **debug:** MYVIMRC is not always set ([735f4d8](https://github.com/folke/snacks.nvim/commit/735f4d8c9de6fcff31bce671495569f345818ea0))
* **notifier:** also handle timeout = false / timeout = true. See [#102](https://github.com/folke/snacks.nvim/issues/102) ([99f1f49](https://github.com/folke/snacks.nvim/commit/99f1f49104d413dabee9ee45bc22366aee97056e))

## [2.2.0](https://github.com/folke/snacks.nvim/compare/v2.1.0...v2.2.0) (2024-11-18)


### Features

* **dashboard:** added new `dashboard` snack ([#77](https://github.com/folke/snacks.nvim/issues/77)) ([d540fa6](https://github.com/folke/snacks.nvim/commit/d540fa607c415b55f5a0d773f561c19cd6287de4))
* **debug:** Snacks.debug.trace and Snacks.debug.stats for hierarchical traces (like lazy profile) ([b593598](https://github.com/folke/snacks.nvim/commit/b593598859b1bb3946671fc78ee1896d32460552))
* **notifier:** global keep when in cmdline ([73b1e20](https://github.com/folke/snacks.nvim/commit/73b1e20d38d4d238316ed391faf3d7ad4c3e71be))

## [2.1.0](https://github.com/folke/snacks.nvim/compare/v2.0.0...v2.1.0) (2024-11-16)


### Features

* **notifier:** allow specifying a minimal level to show notifications. See [#82](https://github.com/folke/snacks.nvim/issues/82) ([ec9cfb3](https://github.com/folke/snacks.nvim/commit/ec9cfb36b1ea2b4bf21b5812791c8bfee3bcf322))
* **terminal:** when terminal terminates too quickly, don't close the window and show an error message. See [#80](https://github.com/folke/snacks.nvim/issues/80) ([313954e](https://github.com/folke/snacks.nvim/commit/313954efdfb064a85df731b29fa9b86bc711044a))


### Bug Fixes

* **docs:** typo in README.md ([#78](https://github.com/folke/snacks.nvim/issues/78)) ([dc0f404](https://github.com/folke/snacks.nvim/commit/dc0f4041dcc8da860bdf84c3bf27d41a6a4debf3))
* **example:** rename file. Closes [#76](https://github.com/folke/snacks.nvim/issues/76) ([00c7a67](https://github.com/folke/snacks.nvim/commit/00c7a674004665999fbea310a322f1e105e1cfb5))
* **notifier:** no gap in border without title/icon ([#85](https://github.com/folke/snacks.nvim/issues/85)) ([bc80bdc](https://github.com/folke/snacks.nvim/commit/bc80bdcc62efd236617dbbd183ce5882aded2145))
* **win:** delay when closing windows ([#81](https://github.com/folke/snacks.nvim/issues/81)) ([d3dc8e7](https://github.com/folke/snacks.nvim/commit/d3dc8e7c27a663e4b30579e4e1ca3313052d0874))

## [2.0.0](https://github.com/folke/snacks.nvim/compare/v1.2.0...v2.0.0) (2024-11-14)


### ⚠ BREAKING CHANGES

* **config:** plugins are no longer enabled by default. Pass any options, or set `enabled = true`.

### Features

* **config:** plugins are no longer enabled by default. Pass any options, or set `enabled = true`. ([797708b](https://github.com/folke/snacks.nvim/commit/797708b0384ddfd66118651c48c3b399e376cb77))
* **health:** added health checks to plugins ([1c4c748](https://github.com/folke/snacks.nvim/commit/1c4c74828fcca382f54817f4446649b201d56557))
* **terminal:** added `Snacks.terminal.colorize()` to replace ansi codes by colors ([519b684](https://github.com/folke/snacks.nvim/commit/519b6841c42c575aec2ffc6c79c4e0a1a13e74bd))


### Bug Fixes

* **lazygit:** not needed to use deprecated fallback for set_hl ([14f076e](https://github.com/folke/snacks.nvim/commit/14f076e039aa876ba086449a45053d847bddb3db))
* **notifier:** disable `colorcolumn` by default ([#66](https://github.com/folke/snacks.nvim/issues/66)) ([7627b81](https://github.com/folke/snacks.nvim/commit/7627b81d9f3453bd2e979d48d3eff2787e6029e9))
* **statuscolumn:** ensure Snacks exists when loading before plugin loaded ([97e0e1e](https://github.com/folke/snacks.nvim/commit/97e0e1ec7f1088ee026efdaa789d102461ad49d4))
* **terminal:** properly deal with args in `vim.o.shell`. Fixes [#69](https://github.com/folke/snacks.nvim/issues/69) ([2ccb70f](https://github.com/folke/snacks.nvim/commit/2ccb70fd3a42d188c95db233bfb7469259d56fb6))
* **win:** take border into account for window position ([#64](https://github.com/folke/snacks.nvim/issues/64)) ([f0e47fd](https://github.com/folke/snacks.nvim/commit/f0e47fd5dc3ccc71cdd8866e2ce82749d3797fbb))

## [1.2.0](https://github.com/folke/snacks.nvim/compare/v1.1.0...v1.2.0) (2024-11-11)


### Features

* **bufdelete:** added `wipe` option. Closes [#38](https://github.com/folke/snacks.nvim/issues/38) ([5914cb1](https://github.com/folke/snacks.nvim/commit/5914cb101070956a73462dcb1c81c8462e9e77d7))
* **lazygit:** allow overriding extra lazygit config options ([d2f4f19](https://github.com/folke/snacks.nvim/commit/d2f4f1937e6fa97a48d5839d49f1f3012067bf45))
* **notifier:** added `refresh` option configurable ([df8c9d7](https://github.com/folke/snacks.nvim/commit/df8c9d7724ade9f3c63277f08b237ac3b32b6cfe))
* **notifier:** added backward compatibility for nvim-notify's replace option ([9b9777e](https://github.com/folke/snacks.nvim/commit/9b9777ec3bba97b3ddb37bd824a9ef9a46955582))
* **words:** add `fold_open` and `set_jump_point` config options ([#31](https://github.com/folke/snacks.nvim/issues/31)) ([5dc749b](https://github.com/folke/snacks.nvim/commit/5dc749b045e62e30a156ca8522416a6d1ca9a959))


### Bug Fixes

* added compatibility with Neovim &gt;= 0.9.4 ([4f99818](https://github.com/folke/snacks.nvim/commit/4f99818b0ab98510ab8987a0427afc515fb5f76b))
* **bufdelete:** opts.wipe. See [#38](https://github.com/folke/snacks.nvim/issues/38) ([0efbb93](https://github.com/folke/snacks.nvim/commit/0efbb93e0a4405b955d574746eb57ef6d48ae386))
* **notifier:** take title/footer into account to determine notification width. Fixes [#54](https://github.com/folke/snacks.nvim/issues/54) ([09a6f17](https://github.com/folke/snacks.nvim/commit/09a6f17eccbb551797f522403033f48e63a25f74))
* **notifier:** update layout on vim resize ([7f9f691](https://github.com/folke/snacks.nvim/commit/7f9f691a12d0665146b25a44323f21e18aa46c24))
* **terminal:** `gf` properly opens file ([#45](https://github.com/folke/snacks.nvim/issues/45)) ([340cc27](https://github.com/folke/snacks.nvim/commit/340cc2756e9d7ef0ae9a6f55cdfbfdca7a9defa7))
* **terminal:** pass a list of strings to termopen to prevent splitting. Fixes [#59](https://github.com/folke/snacks.nvim/issues/59) ([458a84b](https://github.com/folke/snacks.nvim/commit/458a84bd1db856c21f234a504ec384191a9899cf))


### Performance Improvements

* **notifier:** only force redraw for new windows and for updated while search is not active. Fixes [#52](https://github.com/folke/snacks.nvim/issues/52) ([da86b1d](https://github.com/folke/snacks.nvim/commit/da86b1deff9a0b1bb66f344241fb07577b6463b8))
* **win:** don't try highlighting snacks internal filetypes ([eb8ab37](https://github.com/folke/snacks.nvim/commit/eb8ab37f6ac421eeda2570257d2279bd12700667))
* **win:** prevent treesitter and syntax attaching to scratch buffers ([cc80f6d](https://github.com/folke/snacks.nvim/commit/cc80f6dc1b7a286cb06c6321bfeb1046f7a59418))

## [1.1.0](https://github.com/folke/snacks.nvim/compare/v1.0.0...v1.1.0) (2024-11-08)


### Features

* **bufdelete:** optional filter and shortcuts to delete `all` and `other` buffers. Closes [#11](https://github.com/folke/snacks.nvim/issues/11) ([71a2346](https://github.com/folke/snacks.nvim/commit/71a234608ffeebfa8a04c652834342fa9ce508c3))
* **debug:** simple log function to quickly log something to a debug.log file ([fc2a8e7](https://github.com/folke/snacks.nvim/commit/fc2a8e74686c7c347ed0aaa5eb607874ecdca288))
* **docs:** docs for highlight groups ([#13](https://github.com/folke/snacks.nvim/issues/13)) ([964cd6a](https://github.com/folke/snacks.nvim/commit/964cd6aa76f3608c7e379b8b1a483ae19f57e279))
* **gitbrowse:** choose to open repo, branch or file. Closes [#10](https://github.com/folke/snacks.nvim/issues/10). Closes [#17](https://github.com/folke/snacks.nvim/issues/17) ([92da87c](https://github.com/folke/snacks.nvim/commit/92da87c910a9b1421e8baae2e67020565526fba8))
* **notifier:** added history to notifier. Closes [#14](https://github.com/folke/snacks.nvim/issues/14) ([65d8c8f](https://github.com/folke/snacks.nvim/commit/65d8c8f00b6589b44410301b790d97c268f86f85))
* **notifier:** added option to show notifs top-down or bottom-up. Closes [#9](https://github.com/folke/snacks.nvim/issues/9) ([080e0d4](https://github.com/folke/snacks.nvim/commit/080e0d403924e1e62d3b88412a41f3ab22594049))
* **notifier:** allow overriding hl groups per notification ([8bcb2bc](https://github.com/folke/snacks.nvim/commit/8bcb2bc805a1785208f96ad7ad96690eee50c925))
* **notifier:** allow setting dynamic options ([36e9f45](https://github.com/folke/snacks.nvim/commit/36e9f45302bc9c200c76349ecd79a319a5944d8c))
* **win:** added default hl groups for windows ([8c0f10b](https://github.com/folke/snacks.nvim/commit/8c0f10b9dade154d355e31aa3f9c8c0ba212205e))
* **win:** allow setting `ft` just for highlighting without actually changing the `filetype` ([cad236f](https://github.com/folke/snacks.nvim/commit/cad236f9bbe46fbb53127014731d8507a3bc80af))
* **win:** disable winblend when colorscheme is transparent. Fixes [#26](https://github.com/folke/snacks.nvim/issues/26) ([12077bc](https://github.com/folke/snacks.nvim/commit/12077bcf65554b585b1f094c69746df402433132))
* **win:** equalize splits ([e982aab](https://github.com/folke/snacks.nvim/commit/e982aabefdf0b1d00ddd850152921e577cd980cc))
* **win:** util methods to handle buffer text ([d3efb92](https://github.com/folke/snacks.nvim/commit/d3efb92aa546eb160782e24e305f74a559eec212))
* **win:** win:focus() ([476fb56](https://github.com/folke/snacks.nvim/commit/476fb56bfd8e32a2805f46fadafbc4eee7878597))
* **words:** `jump` optionally shows notification with reference count ([#23](https://github.com/folke/snacks.nvim/issues/23)) ([6a3f865](https://github.com/folke/snacks.nvim/commit/6a3f865357005c934e2b5ad2cfadaa038775e9e0))
* **words:** configurable mode to show references. Defaults to n, i, c. Closes [#18](https://github.com/folke/snacks.nvim/issues/18) ([d079fbf](https://github.com/folke/snacks.nvim/commit/d079fbfe354ebfec18c4e1bfd7fee695703e3692))


### Bug Fixes

* **config:** deepcopy config where needed ([6c76f91](https://github.com/folke/snacks.nvim/commit/6c76f913981663ec0dba39686018cbc2ff3220b8))
* **config:** fix reading config during setup. Fixes [#2](https://github.com/folke/snacks.nvim/issues/2) ([0d91a4e](https://github.com/folke/snacks.nvim/commit/0d91a4e364866e407901020b59121883cbfb1cf1))
* **notifier:** re-apply winhl since level might have changed with a replace ([b8cc93e](https://github.com/folke/snacks.nvim/commit/b8cc93e273fd481f2b3b7785f64e301d70fd8e45))
* **notifier:** set default conceallevel=2 ([662795c](https://github.com/folke/snacks.nvim/commit/662795c2855b7bfd5e6ec254e469284dacdabb3f))
* **notifier:** try to keep layout when replacing notifs ([9bdb24e](https://github.com/folke/snacks.nvim/commit/9bdb24e735458ea4fd3974939c33ea78cbba0212))
* **terminal:** dont overwrite user opts ([0b08d28](https://github.com/folke/snacks.nvim/commit/0b08d280b605b2e460c1fd92bc87152e66f14430))
* **terminal:** user options ([334895c](https://github.com/folke/snacks.nvim/commit/334895c5bb2ed04f65800abaeb91ccb0487b0f1f))
* **win:** better winfixheight and winfixwidth for splits ([8be14c6](https://github.com/folke/snacks.nvim/commit/8be14c68a7825fff90ca071f0650657ba88da423))
* **win:** disable sidescroloff in minimal style ([107d10b](https://github.com/folke/snacks.nvim/commit/107d10b52e54828606a645517b55802dd807e8ad))
* **win:** dont center float when `relative="cursor"` ([4991e34](https://github.com/folke/snacks.nvim/commit/4991e347dcc6ff6c14443afe9b4d849a67b67944))
* **win:** properly resolve user styles as last ([cc5ee19](https://github.com/folke/snacks.nvim/commit/cc5ee192caf79446d58cbc09487268aa1f86f405))
* **win:** set border to none for backdrop windows ([#19](https://github.com/folke/snacks.nvim/issues/19)) ([f5602e6](https://github.com/folke/snacks.nvim/commit/f5602e60c325f0c60eb6f2869a7222beb88a773c))
* **win:** simpler way to add buffer padding ([f59237f](https://github.com/folke/snacks.nvim/commit/f59237f1dcdceb646bf2552b69b7e2040f80f603))
* **win:** update win/buf opts when needed ([5fd9c42](https://github.com/folke/snacks.nvim/commit/5fd9c426e850c02489943d7177d9e7fddec5e589))
* **words:** disable notify_jump by default ([9576081](https://github.com/folke/snacks.nvim/commit/9576081e871a801f60367e7180543fa41c384755))


### Performance Improvements

* **notifier:** index queue by id ([5df4394](https://github.com/folke/snacks.nvim/commit/5df4394c60958635bf4651d8d7e25f53f48a3965))
* **notifier:** optimize layout code ([8512896](https://github.com/folke/snacks.nvim/commit/8512896228b3e37e3d02c68fa739749c9f0b9838))
* **notifier:** skip processing queue when free space is smaller than min height ([08190a5](https://github.com/folke/snacks.nvim/commit/08190a545857ef09cb6ada4337fe7ec67d3602a9))
* **win:** skip events when setting buf/win options. Trigger FileType on BufEnter only if needed ([61496a3](https://github.com/folke/snacks.nvim/commit/61496a3ef00bd67afb7affcb4933905910a6283c))

## 1.0.0 (2024-11-06)


### Features

* added debug ([6cb43f6](https://github.com/folke/snacks.nvim/commit/6cb43f603360c6fc702b5d7c928dfde22d886e2f))
* added git ([f0a9991](https://github.com/folke/snacks.nvim/commit/f0a999134738c54dccb78ae462774eb228614221))
* added gitbrowse ([a638d8b](https://github.com/folke/snacks.nvim/commit/a638d8bafef85ac6046cfc02e415a8893e0391b9))
* added lazygit ([fc32619](https://github.com/folke/snacks.nvim/commit/fc32619734e4d3c024b8fc2db941c8ac19d2dd6c))
* added notifier ([44011dd](https://github.com/folke/snacks.nvim/commit/44011ddf0da07d0fa89734d21bb770f01a630077))
* added notify ([f4e0130](https://github.com/folke/snacks.nvim/commit/f4e0130ec3cb0299a3a85c589250c114d46f53c2))
* added toggle ([28c3029](https://github.com/folke/snacks.nvim/commit/28c30296991ac5549b49b7ecfb49f108f70d76ba))
* better buffer/window vars for terminal and float ([1abce78](https://github.com/folke/snacks.nvim/commit/1abce78a8b826943d5055464636cd9fad074b4bb))
* bigfile ([8d62b28](https://github.com/folke/snacks.nvim/commit/8d62b285d5026e3d7c064d435c424bab40d1910a))
* **bigfile:** show message when bigfile was detected ([fdc0d3d](https://github.com/folke/snacks.nvim/commit/fdc0d3d1f80a6be64e85a5a25dc34693edadd73f))
* bufdelete ([cc5353f](https://github.com/folke/snacks.nvim/commit/cc5353f6b3f3f3869e2110b2d3d1a95418653213))
* config & setup ([c98c4c0](https://github.com/folke/snacks.nvim/commit/c98c4c030711a59e6791d8e5cab7550e33ac2d2d))
* **config:** get config for snack with defaults and custom opts ([b3d08be](https://github.com/folke/snacks.nvim/commit/b3d08beb8c60fddc6bfbf96ac9f45c4db49e64af))
* **debug:** added simple profile function ([e1f736d](https://github.com/folke/snacks.nvim/commit/e1f736d71fb9020a09019a49d645d4fe6d9f30db))
* **docs:** better handling of overloads ([038b283](https://github.com/folke/snacks.nvim/commit/038b28319c3a4eba7220a679a5759c06e69b8493))
* ensure Snacks global is available when not using setup ([f0458ba](https://github.com/folke/snacks.nvim/commit/f0458bafb059da9885de4fbab1ae5cb6ce2cd0bb))
* float ([d106107](https://github.com/folke/snacks.nvim/commit/d106107cdccc7ecb9931e011a89df6011eed44c4))
* **float:** added support for splits ([977a3d3](https://github.com/folke/snacks.nvim/commit/977a3d345b6da2b819d9bc4870d3d8a7e026728e))
* **float:** better key mappings ([a171a81](https://github.com/folke/snacks.nvim/commit/a171a815b3acd72dd779781df5586a7cd6ddd649))
* initial commit ([63a24f6](https://github.com/folke/snacks.nvim/commit/63a24f6eb047530234297460a9b7ccd6af0b9858))
* **notifier:** add 1 cell left/right padding and make wrapping work properly ([efc9699](https://github.com/folke/snacks.nvim/commit/efc96996e5a98b619e87581e9527c871177dee52))
* **notifier:** added global keep config option ([f32d82d](https://github.com/folke/snacks.nvim/commit/f32d82d1b705512eb56c901d4d7de68eedc827b1))
* **notifier:** added minimal style ([b29a6d5](https://github.com/folke/snacks.nvim/commit/b29a6d5972943cb8fcfdfb94610d850f0ba050b3))
* **notifier:** allow closing notifs with `q` ([97acbbb](https://github.com/folke/snacks.nvim/commit/97acbbb654d13a0d38792fd6383973a2ca01a2bf))
* **notifier:** allow config of default filetype ([8a96888](https://github.com/folke/snacks.nvim/commit/8a968884098be83acb42f31a573e62b63420268e))
* **notifier:** enable wrapping by default ([d02aa2f](https://github.com/folke/snacks.nvim/commit/d02aa2f7cb49273330fd778818124ddb39838372))
* **notifier:** keep notif open when it's the current window ([1e95800](https://github.com/folke/snacks.nvim/commit/1e9580039b706cfc1f526fea2e46b6857473420b))
* quickfile ([d0ce645](https://github.com/folke/snacks.nvim/commit/d0ce6454f95fe056c65324a0f59a250532a658f3))
* rename ([fa33688](https://github.com/folke/snacks.nvim/commit/fa336883019110b8f525081665bf55c19df5f0aa))
* statuscolumn ([99b1700](https://github.com/folke/snacks.nvim/commit/99b170001592fe054368a220599da546de64894e))
* terminal ([e6cc7c9](https://github.com/folke/snacks.nvim/commit/e6cc7c998afa63eaf126d169f4702953f548d39f))
* **terminal:** allow to override the default terminal implementation (like toggleterm) ([11c9ee8](https://github.com/folke/snacks.nvim/commit/11c9ee83aa133f899dad966224df0e2d7de236f2))
* **terminal:** better defaults and winbar ([7ceeb47](https://github.com/folke/snacks.nvim/commit/7ceeb47e545619dff6dd8853f0a368afae7d3ec8))
* **terminal:** better double esc to go to normal mode ([a4af729](https://github.com/folke/snacks.nvim/commit/a4af729b2489714b066ca03f008bf5fe42c93343))
* **win:** better api to deal with sizes ([ac1a50c](https://github.com/folke/snacks.nvim/commit/ac1a50c810c5f67909921592afcebffa566ee3d3))
* **win:** custom views ([12d6f86](https://github.com/folke/snacks.nvim/commit/12d6f863f73cbd3580295adc5bc546c9d10e9e7f))
* words ([73445af](https://github.com/folke/snacks.nvim/commit/73445af400457722508395d18d2c974965c53fe2))


### Bug Fixes

* **config:** don't change defaults in merge ([6e825f5](https://github.com/folke/snacks.nvim/commit/6e825f509ed0e41dbafe5bca0236157772344554))
* **config:** merging of possible nil values ([f5bbb44](https://github.com/folke/snacks.nvim/commit/f5bbb446ed012361bbd54362558d1f32476206c7))
* **debug:** exclude vimrc from callers ([8845a6a](https://github.com/folke/snacks.nvim/commit/8845a6a912a528f63216ffe4b991b025c8955447))
* **float:** don't use backdrop for splits ([5eb64c5](https://github.com/folke/snacks.nvim/commit/5eb64c52aeb7271a3116751f1ec61b00536cdc08))
* **float:** only set default filetype if no ft is set ([66b2525](https://github.com/folke/snacks.nvim/commit/66b252535c7a78f0cd73755fad22b07b814309f1))
* **float:** proper closing of backdrop ([a528e77](https://github.com/folke/snacks.nvim/commit/a528e77397daea422ff84dde64124d4a7e352bc2))
* **notifier:** modifiable ([fd57c24](https://github.com/folke/snacks.nvim/commit/fd57c243015e6f2c863bb6c89e1417e77f3e0ea4))
* **notifier:** modifiable = false ([9ef9e69](https://github.com/folke/snacks.nvim/commit/9ef9e69620fc51d368fcee830a59bc9279594d43))
* **notifier:** show notifier errors with nvim_err_writeln ([e8061bc](https://github.com/folke/snacks.nvim/commit/e8061bcda095e3e9a3110ce697cdf7155e178d6e))
* **notifier:** sorting ([d9a1f23](https://github.com/folke/snacks.nvim/commit/d9a1f23e216230fcb2060e74056778d57d1d7676))
* simplify setup ([787b53e](https://github.com/folke/snacks.nvim/commit/787b53e7635f322bf42a42279f647340daf77770))
* **win:** backdrop ([71dd912](https://github.com/folke/snacks.nvim/commit/71dd912763918fd6b7fd07dd66ccd16afd4fea78))
* **win:** better implementation of window styles (previously views) ([6681097](https://github.com/folke/snacks.nvim/commit/66810971b9bd08e212faae467d884758bf142ffe))
* **win:** dont error when augroup is already deleted ([8c43597](https://github.com/folke/snacks.nvim/commit/8c43597f10dc2916200a8c857026f3f15fd3ae65))
* **win:** dont update win opt noautocmd ([a06e3ed](https://github.com/folke/snacks.nvim/commit/a06e3ed8fcd08aaf43fc2454bb1b0f935053aca7))
* **win:** no need to set EndOfBuffer winhl ([7a7f221](https://github.com/folke/snacks.nvim/commit/7a7f221020e024da831c2a3d72f8a9a0c330d711))
* **win:** use syntax as fallback for treesitter ([f3b69a6](https://github.com/folke/snacks.nvim/commit/f3b69a617a57597571fcf4263463f989fa3b663d))


### Performance Improvements

* **win:** set options with eventignore and handle ft manually ([80d9a89](https://github.com/folke/snacks.nvim/commit/80d9a894f9d6b2087e0dfee6d777e7b78490ba93))
