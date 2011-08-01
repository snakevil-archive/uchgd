# Makefile: 基于 GNUMake 的自动化安装 UCHGd 的脚本。
#
# AUTHOR    Snakevil Zen <zhengyy@ucweb.com>
# COPYRIGHT © 2011 uc.cn.

HOOK_TYPES = changegroup commit incoming outgoing prechangegroup precommit \
    preoutgoing pretag pretxnchangegroup pretxncommit preupdate tag \
    update

USED_CMDS = awk basename expr hg id sudo useradd usermod wc stat mv

UCHGd: check hgrc user.hg

check:
	$(if $(shell 'which' which 2> /dev/null), , \
		$(error Command 'which' cannot found) \
	)
	$(if $(shell 'which' printf 2> /dev/null), , \
		$(error Command 'printf' cannot found) \
	)
	$(info CHECKING USED COMMANDS)
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	for cmd in $(sort $(USED_CMDS)); do \
		reason=`'which' "$${cmd}" 2> /dev/null`; \
		[ -n "$${reason}" ] || reason='not found'; \
		_item_echo 'checks whether `'"$${cmd}' exists..." "$${reason}"; \
	done; \
	echo '';

clean:
	$(RM) hgrc
	@echo ''

hgrc: $(wildcard hooks/*)
	$(info GATHERING HOOKS)
	@echo '[hooks]' > hgrc; \
	_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	[ '/' = "$(PWD)" ] || PWD="$(PWD)/"; \
	for type in $(HOOK_TYPES); do \
		hint='seeks `'"$${type}'"' hooks...'; \
		[ -f "hooks/$${type}" ] && found="hooks/$${type}\n" || found=''; \
		files=`'ls' "hooks/$${type}."* 2> /dev/null`; \
		[ -n "$${files}" ] && found="$${found}$${files}"; \
		[ -z "$${found}" ] && _item_echo "$${hint}" 'none' || { \
			_item_echo "$${hint}" `echo "$${found}" | 'wc' -l`; \
			for file in "$${found}"; do \
				name=`'basename' "$${file}"`; \
				_item_echo ' +' '`'"$${name}' "; \
				echo "$${name} = $${PWD}$${file}" >> hgrc; \
			done; \
		}; \
		found=; \
	done; \
	echo '';

install:
	$(if $(and $(wildcard hgrc), $(shell id hg 2> /dev/null)), , \
		$(error Run 'make' first) \
	)
	$(info INSTALLING)
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	_item_echo ' * `root'"'"' privilleges maybe required by `sudo'"'"' *'; \
	HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
	_item_echo 'reads home folder...' "$${HOME}"; \
	hint='copy scripts...'; \
	reason=`'sudo' 'cp' -af hgrc "$${HOME}/.hgrc" 2>&1 \
		&& 'sudo' 'cp' -af -t "$${HOME}" hooks ucsh 2>&1 \
		&& cd "$${HOME}" \
		&& 'sudo' 'mkdir' -p repos 2>&1 \
		&& 'sudo' 'mkdir' -p .ssh 2>&1 \
		&& 'sudo' 'chown' -R hg:hg .hgrc ucsh hooks repos .ssh 2>&1 \
		&& 'sudo' 'chmod' 700 .ssh 2>&1 \
	`; \
	[ 0 -eq $$? ] && _item_echo "$${hint}" 'done' || { \
		_item_echo "$${hint}" 'halt'; \
		echo "ABORTED! $${reason}"; \
		exit 1; \
	}; \
	echo 'DONE.';

user.hg:
	$(info CREATING USER 'hg')
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	_item_echo ' * `root'"'"' privilleges maybe required by `sudo'"'"' *'; \
	UID=`'awk' -F':' '"hg"==$$1{print $$3}' /etc/passwd`; \
	GID=`'awk' -F':' '"hg"==$$1{print $$4}' /etc/passwd`; \
	FULL=`'awk' -F':' '"hg"==$$1{print $$5}' /etc/passwd`; \
	HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
	SHELL=`'awk' -F':' '"hg"==$$1{print $$7}' /etc/passwd`; \
	hint='checks whether user `hg'"'"' exists...'; \
	[ -n "$${UID}" ] && { \
		_item_echo "$${hint}" 'yes'; \
		_item_echo 'checks group...' `'id' -gn hg`; \
		_item_echo 'checks user'"'"'s home folder...' "$${HOME}"; \
		hint='checks whether home folder exists...'; \
		[ -d "$${HOME}" ] && { \
			_item_echo "$${hint}" 'yes'; \
			OWNSHIP=`'stat' -c'%U:%G' "$${HOME}"`; \
			_item_echo 'checks ownship of home folder...' "$${OWNSHIP}"; \
			[ 'hg:hg' = "$${OWNSHIP}" ] || { \
				hint='fixes ownship of home folder to `hg:hg'"'..."; \
				reason=`'sudo' 'chown' -R hg:hg "$${HOME}" 2>&1`; \
				[ 0 -eq $$?] && _item_echo "$${hint}" 'succeed' || { \
					_item_echo "$${hint}" 'failed'; \
					echo "ABORTED! $${reason}"; \
					exit 1; \
				}; \
			}; \
		} || { \
			_item_echo "$${hint}" 'no'; \
			hint='creates home folder...'; \
			reason=`'sudo' -u hg 'mkdir' -p "$${HOME}" 2>&1`; \
			[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
				_item_echo "$${hint}" 'failed'; \
				echo "ABORTED! $${reason}"; \
				exit 1; \
			}; \
		}; \
		hint=''; \
		_item_echo 'checks user'"'"'s fullname...' "$${FULL}"; \
		[ 'sMercurial' = "s$${FULL}" ] || { \
			FULL='Mercurial'; \
			cmd=" -c'$${FULL}' "; \
			hint='fixes user'"'"'s fullname'; \
		}; \
		_item_echo 'checks user'"'"'s login shell...' "$${SHELL}"; \
		[ "s$${HOME}/ucsh" = "s$${SHELL}" ] || { \
			SHELL="$${HOME}/ucsh"; \
			cmd="$${cmd} -s'$${SHELL}' "; \
			[ -n "$${hint}" ] && hint="$${hint} and login shell..." \
				|| hint='fixes user'"'"'s login shell...'; \
		}; \
		[ -z "$${cmd}" ] || { \
			reason=`eval "'sudo' 'usermod' $${cmd} hg 2>&1"`; \
			[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
				_item_echo "$${hint}" 'failed'; \
				echo "ABORTED! $${reason}"; \
				exit 1; \
			}; \
		}; \
	} || { \
		_item_echo "$${hint}" 'no'; \
		FULL='Mercurial'; \
		for dir in '/home' '/srv' '/var' '/tmp'; do \
			[ -d "$${dir}" ] && { \
				HOME="$${dir}/hg"; \
				break; \
			}; \
		done; \
		SHELL="$${HOME}/ucsh"; \
		hint='creates user account...'; \
		reason=`'sudo' 'useradd' -c"$${FULL}" -d"$${HOME}" -s"$${SHELL}" -l -m -r hg 2>&1`; \
		[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
			_item_echo "$${hint}" 'failed'; \
			echo "ABORTED! $${reason}"; \
			exit 1; \
		}; \
	}; \
	echo '';

.PHONY: UCHGd check install

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
