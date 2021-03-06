all: minit msvc pidfilehack hard-reboot write_proc killall5 shutdown \
minit-update serdo

#CFLAGS=-pipe -march=i386 -fomit-frame-pointer -Os -I../dietlibc/include
CC=gcc
CFLAGS=-Wall -W -pipe -fomit-frame-pointer -Os
CROSS=
#CROSS=arm-linux-
LDFLAGS=-s
MANDIR=/usr/man

path = $(subst :, ,$(PATH))
include = /usr/include

diet_path = $(foreach dir,$(path),$(wildcard $(dir)/diet))
ifeq ($(strip $(diet_path)),)
ifneq ($(wildcard /opt/diet/bin/diet),)
DIET=/opt/diet/bin/diet
else
DIET=
endif
else
DIET:=$(strip $(diet_path))
endif

ifneq ($(DEBUG),)
CFLAGS+=-g
LDFLAGS+=-g
else
CFLAGS+=-O2 -fomit-frame-pointer -Wno-unused-result
LDFLAGS+=-s
ifneq ($(DIET),)
DIET+=-Os
endif
endif

ifneq ($(DIET),)

libowfat_path = $(strip $(foreach dir,$(include),$(wildcard $(dir)/libowfat/textcode.h)))
ifneq ($(libowfat_path),)
CFLAGS+=$(foreach fnord,$(libowfat_path),-I$(dir $(fnord))) -DHAVE_LIBOWFAT
LDFLAGS+=$(foreach fnord,$(libowfat_path),-L$(dir $(fnord)))
LDLIBS=-lowfat
endif

endif

ifeq ($(libowfat_path),)
PLATFORM_OBJS = platform/byte_equal.o platform/errmsg.o platform/fmt_str.o \
		platform/fmt_ulong.o platform/scan_ulong.o platform/str_chr.o

libplatform.a: $(PLATFORM_OBJS)

PLATFORM_LIBS=libplatform.a
endif

minit: minit.o split.o openreadclose.o opendevconsole.o $(PLATFORM_LIBS)
msvc: msvc.o $(PLATFORM_LIBS)
minit-update: minit-update.o split.o openreadclose.o $(PLATFORM_LIBS)
serdo: serdo.o $(PLATFORM_LIBS)

shutdown: shutdown.o split.o openreadclose.o opendevconsole.o $(PLATFORM_LIBS)
	$(DIET) $(CROSS)$(CC) $(LDFLAGS) -o shutdown $^

%.o: %.c
	$(DIET) $(CROSS)$(CC) $(CFLAGS) -c $< -o $@

%: %.o
	$(DIET) $(CROSS)$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

%.a:
	$(CROSS)ar cr $@ $^
	-$(CROSS)ranlib $@

clean:
	rm -f *.o minit msvc pidfilehack hard-reboot write_proc killall5 \
	shutdown minit-update serdo libplatform.a platform/*.o

test: test.c
	gcc -nostdlib -o $@ $^ -I../dietlibc/include ../dietlibc/start.o ../dietlibc/dietlibc.a

pidfilehack: pidfilehack.c
	$(DIET) $(CROSS)$(CC) $(CFLAGS) -o $@ $^

hard-reboot: hard-reboot.c
	$(DIET) $(CROSS)$(CC) $(CFLAGS) -o $@ $^

write_proc: write_proc.c
	$(DIET) $(CROSS)$(CC) $(CFLAGS) -o $@ $^

killall5: killall5.c
	$(DIET) $(CROSS)$(CC) $(CFLAGS) -o $@ $^

install-files:
	install -d $(DESTDIR)/etc/minit $(DESTDIR)/sbin $(DESTDIR)/bin $(DESTDIR)$(MANDIR)/man8
	install minit pidfilehack $(DESTDIR)/sbin
	install write_proc hard-reboot minit-update $(DESTDIR)/sbin
	install msvc serdo $(DESTDIR)/bin
	if test -f $(DESTDIR)/sbin/shutdown; then install shutdown $(DESTDIR)/sbin/mshutdown; else install shutdown $(DESTDIR)/sbin/shutdown; fi
	test -f $(DESTDIR)/sbin/init || ln $(DESTDIR)/sbin/minit $(DESTDIR)/sbin/init
	install -m 644 hard-reboot.8 minit-list.8 minit-shutdown.8 minit-update.8 minit.8 msvc.8 pidfilehack.8 serdo.8 $(DESTDIR)$(MANDIR)/man8

install-fifos:
	-mkfifo -m 600 $(DESTDIR)/etc/minit/in $(DESTDIR)/etc/minit/out

install: install-files install-fifos

VERSION=minit-$(shell head -n 1 CHANGES|sed 's/://')
CURNAME=$(notdir $(shell pwd))

tar: clean rename
	cd ..; tar cvvf $(VERSION).tar.bz2 --use=bzip2 --exclude CVS $(VERSION)

rename:
	if test $(CURNAME) != $(VERSION); then cd .. && mv $(CURNAME) $(VERSION); fi

