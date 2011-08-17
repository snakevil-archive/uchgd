# Makefile~dist.mk: 自动打包 UCHGd 的脚本。
#
# AUTHOR    Snakevil Zen <zhengyy@ucweb.com>
# COPYRIGHT © 2011 uc.cn.

ifeq "$(wildcard .hg/store)" ".hg/store"

DIST_FILE = dist./uchgd-$(strip $(if $(shell [ 'tip' = `'hg' parents --template '{tags}'` ] || echo 1), \
	$(shell 'hg' parents --template 'v{tags}'), \
	$(shell 'hg' parents --template 'nr{rev}') \
)).tar.gz

dist: $(DIST_FILE)
	$(warning Runs '$@'...)

$(DIST_FILE):
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	'hg' archive -X '.*' '$(DIST_FILE)'

endif

ifneq "$(wildcard dist./uchgd-*.tar.gz)" ""

distclean:
	$(warning Runs '$@'...)
	$(RM) -R dist.

endif

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
