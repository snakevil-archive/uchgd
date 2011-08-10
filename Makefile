# Makefile: 基于 GNUMake 的自动化安装 UCHGd 的脚本。
#
# AUTHOR    Snakevil Zen <zhengyy@ucweb.com>
# COPYRIGHT © 2011 uc.cn.

# {{{ 基础约定

SHELL = /bin/sh

HOOK_TYPES = changegroup commit incoming outgoing prechangegroup precommit \
    preoutgoing pretag pretxnchangegroup pretxncommit preupdate tag \
    update

USED_CMDS = awk basename expr hg id sudo useradd usermod wc stat mv grep \
	sort sed cat head mkdir touch

# }}}

# {{{ 基础列表计算

HOOK_FILES = $(foreach hook, $(wildcard hooks/*), \
		$(shell test -x $(hook) &> /dev/null && echo "$(hook)") \
	)

DEPARTS =

CP = 'cp' -af

CPB = $(CP) -bS'~backup-by-uchgd~$(shell 'date' +'%y%m%d-%H%M')'

# }}}

# {{{ 终极目标：all

all: build/cmds-chk.log build/authorized_keys.all build/hgrc build/sshd_config \
		build/usermod.sh build/sample
	$(CP) build/authorized_keys.all build/authorized_keys

# }}}

# {{{ GNU标准目标：install、uninstall、clean、check、installcheck

install: build/cmds-chk.log build/authorized_keys build/hgrc build/sshd_config \
		build/usermod.sh build/sample permq repos/sample.auth ucsh
	'sudo' '$(SHELL)' build/usermod.sh
	'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd > build/destdir
	'sudo' -u hg $(CPB) -r -t `'cat' build/destdir` hooks permq repos ucsh
	'sudo' -u hg $(CPB) build/authorized_keys `'cat' build/destdir`/.ssh/
	'sudo' -u hg $(CPB) build/hgrc `'cat' build/destdir`/.hgrc
	'sudo' -u hg $(CPB) build/sample `'cat' build/destdir`/repos/
	'sudo' $(CPB) build/sshd_config /etc/ssh/sshd_config \
		&& 'sudo' 'chown' root:root /etc/ssh/sshd_config
	'sudo' /etc/init.d/ssh restart > /dev/null

uninstall:
	'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd > build/destdir
	[ 1 -eq `'cat' build/destdir | 'wc' -l` ] || exit 1
	cd `'cat' build/destdir` \
		&& 'sudo' $(RM) -R .hgrc hooks permq repos/sample.auth .ssh/authorized_keys \
			ucsh
	read -p'Also destroy the `sample'"'"' repository? Type `yes'"'"' to do it: ' c \
		&& [ 'xyes' = 'x'`echo -n "$${c}"` ] \
		&& 'sudo' $(RM) -R `'cat' build/destdir`/repos/sample \
		|| exit 0

clean:
	$(RM) -R build/*

check: build/cmds-chk.log
	@echo Passed.

installcheck: build/cmds-chk.log build/usermod.sh
	@echo Passed.

# }}}

# {{{ 自定义目标：dept.*、build/*

define DEPART_MAKE_template
dept.$(strip $(1)): build/cmds-chk.log build/authorized_keys.$(strip $(1)) \
		build/hgrc build/sshd_config build/usermod.sh \
		build/sample
	$$(CP) build/authorized_keys.$(strip $(1)) build/authorized_keys

build/authorized_keys.$(strip $(1)): $$(wildcard pubkeys/$(strip $(1))/*.pub)
	$$(warning Generates '$$@'...)
	'mkdir' -p '$$(dir $$@)'
	$$(RM) '$$@'
	$$(foreach pubkey, $$^, \
		echo -n 'no-pty,no-port-forwarding,no-X11-forwarding,' >> '$$@'; \
		echo -n 'no-agent-forwarding,environment="USER=' >> '$$@'; \
		echo -n '$$(strip $$(basename $$(notdir $$(pubkey))))" ' >> '$$@'; \
		'cat' '$$(pubkey)' >> '$$@'; \
	)

DEPARTS += dept.$(strip $(1))
endef

$(foreach depart, $(wildcard pubkeys/*), \
	$(if $(wildcard $(depart)/*.pub), \
		$(eval $(call DEPART_MAKE_template, $(notdir $(depart)))) \
	) \
)

build/authorized_keys.all: $(wildcard pubkeys/*/*.pub)
	$(warning Generates '$@'...)
	'mkdir' -p '$(dir $@)'
	$(RM) '$@'
	$(foreach pubkey, $^, \
		echo -n 'no-pty,no-port-forwarding,no-X11-forwarding,' >> '$@'; \
		echo -n 'no-agent-forwarding,environment="USER=' >> '$@'; \
		echo -n '$(strip $(basename $(notdir $(pubkey))))" ' >> '$@'; \
		'cat' '$(pubkey)' >> '$@'; \
	)

build/hgrc: $(HOOK_FILES)
	$(warning Generates '$@'...)
	'mkdir' -p '$(dir $@)'
	echo '[hooks]' > '$@'
	$(foreach hook, $(sort $(notdir $^)), \
		echo '$(strip $(hook)) = /home/hg/hooks/$(strip $(hook))' >> '$@'; \
	)

build/sshd_config: /etc/ssh/sshd_config
	$(warning Generates '$@'...)
	'mkdir' -p '$(dir $@)'
	'awk' -F'Snakevil Zen' ' \
		/^#+[[:space:]]*Added[[:space:]]+by[[:space:]]+UCHGd/ { \
			skip = 2; \
			uchgd = 1; \
			print "### Added by UCHGd on "strftime("%e %b %Y")"."; \
		} \
		!uchgd && /^[[:space:]]*GSSAPIAuthentication[[:space:]]+no([[:space:]]|$$)/ { \
				gaa = 1; \
		} \
		!uchgd && /^[[:space:]]*GSSAPIAuthentication[[:space:]]+yes([[:space:]]|$$)/ { \
			skip = 1; \
			gaa = 0; \
			print "#"$$0; \
		} \
		!uchgd && /^[[:space:]]*PermitUserEnvironment[[:space:]]+no([[:space:]]|$$)/ { \
			skip = 1; \
			pue = 0; \
			print "#"$$0; \
		} \
		!uchgd && /^[[:space:]]*PermitUserEnvironment[[:space:]]+yes([[:space:]]|$$)/ { \
			pue = 1; \
		} \
		!uchgd && /^[[:space:]]*UseDNS[[:space:]]+no([[:space:]]|$$)/ { \
			ud = 1; \
		} \
		!uchgd && /^[[:space:]]*UseDNS[[:space:]]+yes([[:space:]]|$$)/ { \
			skip = 1; \
			ud = 0; \
			print "#"$$0; \
		} \
		!skip{print} \
		{if(1==skip)skip=0} \
		END { \
			if (!uchgd) { \
				print ""; \
				print "### Added by UCHGd on "strftime("%e %b %Y")"."; \
			} \
			if (!gaa) \
				print "GSSAPIAuthentication no"; \
			if (!pue) \
				print "PermitUserEnvironment yes"; \
			if (!ud) \
				print "UseDNS no"; \
		} \
		' '$<' > '$@'

build/cmds-chk.log:
	$(warning Generates '$@'...)
	$(foreach cmd, which printf $(sort $(USED_CMDS)), \
		$(if $(shell 'which' $(cmd) 2> /dev/null), , \
			$(error Command '$(cmd)' cannot be found) \
		) \
	)
	'mkdir' -p '$(dir $@)'
	'which' which printf $(sort $(USED_CMDS)) > '$@'

build/usermod.sh:
	$(warning Generates '$@'...)
	'mkdir' -p '$(dir $@)'
	$(RM) '$@'
	$(if $(shell 'awk' -F':' '"hg"==$$1{print}' /etc/passwd), \
		UID=`'awk' -F':' '"hg"==$$1{print $$3}' /etc/passwd`; \
		GID=`'awk' -F':' '"hg"==$$1{print $$4}' /etc/passwd`; \
		FULL=`'awk' -F':' '"hg"==$$1{print $$5}' /etc/passwd`; \
		HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
		SHELL=`'awk' -F':' '"hg"==$$1{print $$7}' /etc/passwd`; \
		[ -d "$${HOME}" ] || { \
			echo "'mkdir' -p '$${HOME}'" >> '$@'; \
		}; \
		echo "'chown' hg '$${HOME}'" >> '$@'; \
		echo "'sudo' -u hg 'mkdir' -p '$${HOME}/.ssh'" >> '$@'; \
		echo "'chmod' 700 '$${HOME}/.ssh'" >> '$@'; \
		[ 'xMercurial' = "x$${FULL}" ] || echo "'usermod' -c'Mercurial' hg" >> '$@'; \
		[ "$${HOME}/ucsh" = "$${SHELL}" ] || echo "'usermod' -s'$${HOME}/ucsh' hg" >> '$@'; \
	, \
		echo "'useradd' -c'Mercurial' -d'/home/hg' -s'/home/hg/ucsh' -l -m -r hg" > '$@'; \
		echo "'sudo' -u hg 'mkdir' -p '/home/hg/.ssh'" >> '$@'; \
		echo "'chmod' 700 '/home/hg/.ssh'" >> '$@'; \
	)

build/sample: build/dummy
	$(warning Generates '$@'...)
	'mkdir' -p '$(dir $@)'
	$(RM) -R '$@'
	'hg' init '$@'
	cd $< && 'hg' push $(abspath $@) > /dev/null

build/dummy:
	$(warning Generates '$@'...)
	'mkdir' -p '$(dir $@)'
	$(RM) -R '$@'
	'hg' init '$@'
	cd $@ && 'hg' branch stable > /dev/null
	echo 'syntax: glob' > '$@/.hgignore'
	echo '.*' >> '$@/.hgignore'
	cd $@ && 'hg' add .hgignore
	cd $@ && 'hg' ci -m'PROJECT INITIALIZED' -u'Snakevil Zen <zhengyy@ucweb.com>'

# }}}

.PHONY: check installcheck

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
