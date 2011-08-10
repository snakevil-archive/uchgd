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
	sort sed cat head mkdir touch date

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
		build/usermod.sh build/sample permq repos/sample.auth ucsh \
		build/home.data
	'sudo' '$(SHELL)' build/usermod.sh
	'sudo' -u hg $(CPB) -r -t `'cat' build/home.data` hooks permq repos ucsh
	'sudo' -u hg $(CPB) build/authorized_keys `'cat' build/home.data`/.ssh/
	'sudo' -u hg $(CPB) build/hgrc `'cat' build/home.data`/.hgrc
	'sudo' -u hg $(CPB) build/sample `'cat' build/home.data`/repos/
	'sudo' $(CPB) build/sshd_config /etc/ssh/sshd_config \
		&& 'sudo' 'chown' root:root /etc/ssh/sshd_config
	'sudo' /etc/init.d/ssh restart > /dev/null

uninstall:
	'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd > build/home.data
	[ 1 -eq `'cat' build/home.data | 'wc' -l` ] || exit 1
	cd `'cat' build/home.data` \
		&& 'sudo' $(RM) -R .hgrc hooks permq repos/sample.auth .ssh/authorized_keys \
			ucsh
	read -p'Also destroy the `sample'"'"' repository? Type `yes'"'"' to do it: ' c \
		&& [ 'xyes' = 'x'`echo -n "$${c}"` ] \
		&& 'sudo' $(RM) -R `'cat' build/home.data`/repos/sample \
		|| exit 0

clean:
	$(RM) -R build

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

build/authorized_keys.$(strip $(1)): build/ $$(wildcard pubkeys/$(strip $(1))/*.pub)
	$$(warning Generates '$$@'...)
	$$(RM) '$$@'
	$$(foreach pubkey, $$(sort $$(wordlist 2, 198486, $$^)), \
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

build/:
	$(warning Generates '$@'...)
	'mkdir' -p '$@'

build/authorized_keys.all: build/ $(wildcard pubkeys/*/*.pub)
	$(warning Generates '$@'...)
	$(RM) '$@'
	$(foreach pubkey, $(sort $(wordlist 2, 198486, $^)), \
		echo -n 'no-pty,no-port-forwarding,no-X11-forwarding,' >> '$@'; \
		echo -n 'no-agent-forwarding,environment="USER=' >> '$@'; \
		echo -n '$(strip $(basename $(notdir $(pubkey))))" ' >> '$@'; \
		'cat' '$(pubkey)' >> '$@'; \
	)

build/cmds-chk.log: build/
	$(warning Generates '$@'...)
	$(foreach cmd, which printf $(sort $(USED_CMDS)), \
		$(if $(shell 'which' $(cmd) 2> /dev/null), , \
			$(error Command '$(cmd)' cannot be found) \
		) \
	)
	'which' which printf $(sort $(USED_CMDS)) > '$@'

build/dummy: build/
	$(warning Generates '$@'...)
	$(RM) -R '$@'
	'hg' init '$@'
	cd $@ && 'hg' branch stable > /dev/null
	echo 'syntax: glob' > '$@/.hgignore'
	echo '.*' >> '$@/.hgignore'
	cd $@ && 'hg' add .hgignore
	cd $@ && 'hg' ci -m'PROJECT INITIALIZED' -u'Snakevil Zen <zhengyy@ucweb.com>'

build/hgrc: build/ build/home.data $(HOOK_FILES)
	$(warning Generates '$@'...)
	echo '[hooks]' > '$@'
	$(foreach hook, $(sort $(notdir $(wordlist 3, 198486, $^))), \
		echo '$(strip $(hook)) = '`'cat' build/home.data`'/hooks/$(strip $(hook))' >> '$@'; \
	)

build/home.data: build build/usermod.sh
	$(warning Generates '$@'...)
	'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd > build/home.data
	[ 1 -eq `'cat' build/home.data | 'wc' -l` ] || exit 1

build/sample: build/ build/dummy
	$(warning Generates '$@'...)
	$(RM) -R '$@'
	'hg' init '$@'
	cd $(lastword $^) && 'hg' push $(abspath $@) > /dev/null

build/sshd_config: build/ /etc/ssh/sshd_config
	$(warning Generates '$@'...)
	date=`'date' +'%e %b %Y'`; \
	'awk' -F'Snakevil Zen' -v"today=$${date}" ' \
		/^#+[ \t]*Added[ \t]+by[ \t]+UCHGd/ { \
			skip = 2; \
			uchgd = 1; \
			print "### Added by UCHGd on "today"."; \
		} \
		!uchgd && /^[ \t]*GSSAPIAuthentication[ \t]+no([ \t]|$$)/ { \
				gaa = 1; \
		} \
		!uchgd && /^[ \t]*GSSAPIAuthentication[ \t]+yes([ \t]|$$)/ { \
			skip = 1; \
			gaa = 0; \
			print "#"$$0; \
		} \
		!uchgd && /^[ \t]*PermitUserEnvironment[ \t]+no([ \t]|$$)/ { \
			skip = 1; \
			pue = 0; \
			print "#"$$0; \
		} \
		!uchgd && /^[ \t]*PermitUserEnvironment[ \t]+yes([ \t]|$$)/ { \
			pue = 1; \
		} \
		!uchgd && /^[ \t]*UseDNS[ \t]+no([ \t]|$$)/ { \
			ud = 1; \
		} \
		!uchgd && /^[ \t]*UseDNS[ \t]+yes([ \t]|$$)/ { \
			skip = 1; \
			ud = 0; \
			print "#"$$0; \
		} \
		!skip{print} \
		{if(1==skip)skip=0} \
		END { \
			if (!uchgd) { \
				print ""; \
				print "### Added by UCHGd on "today"."; \
			} \
			if (!gaa) \
				print "GSSAPIAuthentication no"; \
			if (!pue) \
				print "PermitUserEnvironment yes"; \
			if (!ud) \
				print "UseDNS no"; \
		} \
		' '$(lastword $^)' > '$@'

build/usermod.sh: build/
	$(warning Generates '$@'...)
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

# }}}

.PHONY: check installcheck

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
