NAME		:= pvala
MAJVER		:= 0
MINVER		:= 22
PATVER		:= 1
VERSION		:= $(MAJVER).$(MINVER).$(PATVER)
PACKAGE_SUFFIX	:= -$(MAJVER).$(MINVER)
PACKAGE_BUGREPORT := davehome@redthumb.info.tm
PACKAGE_URL	:= https://github.com/xdave/$(NAME)
PREFIX		:= /usr/local
BINDIR		:= $(PREFIX)/bin
LIBDIR		:= $(PREFIX)/lib
LIBEXECDIR	:= $(PREFIX)/libexec/$(NAME)$(PACKAGE_SUFFIX)
INCLUDEDIR	:= $(PREFIX)/include/$(NAME)$(PACKAGE_SUFFIX)
DATAROOTDIR	:= $(PREFIX)/share/$(NAME)$(PACKAGE_SUFFIX)
VAPIDIR		:= $(DATAROOTDIR)/vapi
PACKAGE_DATADIR := $(DATAROOTDIR)

PROGS		:= pkg-config sed valac
PKGS		:= glib-2.0 gobject-2.0 gmodule-2.0

PC		:= lib$(NAME)$(PACKAGE_SUFFIX).pc

GENERATED	:= $(PC) version.h config.h common.mk Makefile
SUBDIRS		:= gee ccode codegen pvala compiler vala-codegen-posix

CLEANUP		:= $(shell rm -f $(GENERATED))

VALAC		:=	valac

PVALAC		:=	$(NAME)c
LIBPVALA	:=	lib$(NAME)$(PACKAGE_SUFFIX).so
LIBPOSIX	:=	libposix$(PACKAGE_SUFFIX).so
PVALAC_SRC	+=	$(wildcard compiler/*.vala)
LIBPVALA_SRC	+=	$(wildcard gee/*.vala) $(wildcard ccode/*.vala)	\
			$(wildcard codegen/*.vala) $(wildcard pvala/*.vala)
LIBPOSIX_SRC	+=	$(wildcard vala-codegen-posix/*.vala)
VPKG		+=	$(patsubst %,--pkg=%,$(PKGS))
VFLAGS		+=	--nostdpkg $(VPKG)
VFLAGS		+=	--vapidir=vapi vapi/config.vapi

all: check_progs check_pkgs $(GENERATED) gen_source
	@echo "Done. Now type 'make'."

check_progs:
	@for prog in $(PROGS); do					\
		echo "Checking for program '$${prog}' ...";		\
		$${prog} --version 1>/dev/null 2>/dev/null;		\
		if [ ! $$? -eq 0 ]; then				\
			echo "Program '$${prog}' not found!";		\
			exit 1;						\
		fi;							\
	done

check_pkgs:
	@for pkg in $(PKGS); do						\
		echo "Checking for package '$${pkg}' ...";		\
		pkg-config --exists $${pkg} 1>/dev/null 2>/dev/null;	\
		if [ ! $$? -eq 0 ]; then				\
			echo "Package '$${pkg}' not found!";		\
			exit 1;						\
		fi;							\
	done

$(PC): lib$(NAME).pc.in
	@echo "Generating $@ ..."
	@sed								\
		-e "s|@prefix@|$(PREFIX)|g"				\
		-e "s|@exec_prefix@|$(PREFIX)|g"			\
		-e "s|@libdir@|$(LIBDIR)|g"				\
		-e "s|@bindir@|$(BINDIR)|g"				\
		-e "s|@includedir@|$(INCLUDEDIR)|g"			\
		-e "s|@datarootdir@|$(DATAROOTDIR)|g"			\
		-e "s|@datadir@|$(DATAROOTDIR)|g"			\
		-e "s|@VERSION@|$(VERSION)|g"				\
		-e "s|@PACKAGE_SUFFIX@|$(PACKAGE_SUFFIX)|g"		\
		$< > $@

common.mk: common.mk.in
	@echo "Generating $@ ..."
	@sed							\
		-e "s|@NAME@|${NAME}|g"				\
		-e "s|@MAJVER@|${MAJVER}|g"			\
		-e "s|@MINVER@|${MINVER}|g"			\
		-e "s|@PATVER@|${PATVER}|g"			\
		-e "s|@VERSION@|${VERSION}|g"			\
		-e "s|@PACKAGE_SUFFIX@|${PACKAGE_SUFFIX}|g"	\
		-e "s|@PACKAGE_BUGREPORT@|${PACKAGE_BUGREPORT}|g" \
		-e "s|@PACKAGE_URL@|${PACKAGE_URL}|g"		\
		-e "s|@PREFIX@|${PREFIX}|g"			\
		-e "s|@BINDIR@|${BINDIR}|g"			\
		-e "s|@LIBDIR@|${LIBDIR}|g"			\
		-e "s|@LIBEXECDIR@|${LIBEXECDIR}|g"		\
		-e "s|@INCLUDEDIR@|${INCLUDEDIR}|g"		\
		-e "s|@DATAROOTDIR@|${DATAROOTDIR}|g"		\
		-e "s|@VAPIDIR@|${VAPIDIR}|g"			\
		-e "s|@PKGS@|${PKGS}|g"				\
		-e "s|@PC@|${PC}|g"				\
		-e "s|@GENERATED@|${GENERATED}|g"		\
		-e "s|@SUBDIRS@|$(SUBDIRS)|g"			\
		$< > $@

Makefile: Makefile.in
	@echo "Generating $@ ..."
	@cat $< > $@

version.h: version.h.in
	@echo "Generating $@ ..."
	@sed -e "s|@VERSION@|${VERSION}|g" $< > $@

config.h: config.h.in
	@echo "Generating $@ ..."
	@sed								\
		-e "s|@NAME@|$(NAME)|g"					\
		-e "s|@VERSION@|$(VERSION)|g"				\
		-e "s|@PACKAGE_BUGREPORT@|$(PACKAGE_BUGREPORT)|g"	\
		-e "s|@PACKAGE_SUFFIX@|$(PACKAGE_SUFFIX)|g"		\
		-e "s|@PACKAGE_URL@|$(PACKAGE_URL)|g"			\
		-e "s|@LIBEXECDIR@|$(LIBEXECDIR)|g"			\
		-e "s|@DATAROOTDIR@|$(DATAROOTDIR)|g"			\
		$< > $@

gen_source:
	@echo "Generating source for target: $(LIBPVALA) ..."
	@valac $(VFLAGS) -C $(LIBPVALA_SRC) -H lib$(NAME)$(PACKAGE_SUFFIX).h	\
		--use-header=lib$(NAME)$(PACKAGE_SUFFIX).h			\
		--vapi=lib$(NAME)$(PACKAGE_SUFFIX).vapi
	@echo "Generating source for target: $(PVALAC) ..."
	@valac $(VFLAGS) -C $(PVALAC_SRC) --vapidir=. 				\
		--pkg=lib$(NAME)$(PACKAGE_SUFFIX)
	@echo "Generating source for target: $(LIBPOSIX) ..."
	@valac $(VFLAGS) -C $(LIBPOSIX_SRC) --vapidir=. \
		--pkg=lib$(NAME)$(PACKAGE_SUFFIX)

.PHONY: $(PROGS) $(PKGS) check_progs check_pkgs gen_source
