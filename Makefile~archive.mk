# Makefile~archive.mk: 自动备份导出 hg 帐号下的生产版本库的脚本。
#
# AUTHOR    Snakevil Zen <zhengyy@ucweb.com>
# COPYRIGHT © 2011 uc.cn.

HG_REPOS = $(foreach file, $(wildcard $(HG_HOME)/repos/*), \
	$(if $(wildcard $(file)/.hg/store/data/*), $(file)) \
)

ifneq "$(strip $(HG_REPOS))" ""

BACKUP_FILES = $(addprefix export/, $(foreach repos, $(HG_REPOS), \
		$(addprefix $(notdir $(repos)), $(shell cd '$(repos)' \
				&& 'hg' log -r'tip' --template '-rev{rev}~{node|short}.tar.gz' 2> /dev/null \
			) \
		) \
	) \
)

archive: $(BACKUP_FILES)
	$(warning Runs '$@'...)

define ARCHIVE_MAKE_template
$(2): $(1) $(wildcard $(1).auth)
	$$(warning Archives '$$<'...)
	'mkdir' -p $$(@D)
	$$(RM) '$$@'
	'tar' cf '$$(basename $$@)' -C '$$(dir $$<)' '$$(notdir $$<)'
	$(if $(wildcard $(1).auth), \
		'tar' rf '$$(basename $$@)' -C '$$(dir $$<)' '$$(notdir $$(lastword $$^))' \
	)
	'gzip' -9 '$$(basename $$@)'
endef

$(foreach repos, $(HG_REPOS), \
	$(eval $(call ARCHIVE_MAKE_template, \
			$(repos), \
			$(addprefix export/$(notdir $(repos)), \
				$(shell cd '$(repos)' \
					&& 'hg' log -r'tip' --template '-rev{rev}~{node|short}.tar.gz' 2> /dev/null \
				) \
			) \
		) \
	) \
)

endif

ifneq "$(wildcard export/*-rev*~????????????.tar.gz)" ""

archiveclean:
	$(warning Runs '$@'...)
	$(RM) -R export

restore: $(wildcard export/*-rev*~????????????.tar.gz)
	$(warning Runs '$@'...)
	$(if $(wildcard $(HG_HOME)/repos), , $(error 'UCHGd' should be installed first))
	$(foreach archive, $^, \
		$(if $(wildcard $(HG_HOME)/repos/$(shell 'tar' tf '$(archive)' | 'head' -n1)), , \
			'sudo' -u hg 'tar' zxf '$(archive)' -C '$(HG_HOME)/repos'; \
		) \
	)

endif

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
