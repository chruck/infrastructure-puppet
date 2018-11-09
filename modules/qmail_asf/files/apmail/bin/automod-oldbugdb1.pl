#!/usr/bin/perl -w
#
# Buglist auto-moderation
#
# (adapted to the needs of the old bug-list at apache-bugdb@apache.org)
#
# If all required headers are found in the analyzed message, the script
# simply returns 0 so that qmail continues in delivering the message.
#
# If only one header is missing from the analyzed message, the script
# returns 99 and prints out a warning. qmail then stops processing and
# the message gets 'bit-bucketed'.
#
# Alternatively you may return 100 and print out an error message so
# that the mail gets rejected and is bounced back to the sender.

use strict;

my $dump = 1;
my $dumpfile = '/var/log/blackholedspam';

my @required_headers = (
	'Message-I[Dd]: \<[0-9]{14}\.[0-9]{1,9}\.qmail\@apache\.org\>'
);

my $recvd = 0;
my ($f, $headers);
my $sndr = $ENV{SENDER} || "[N/A]";
my $recp = $ENV{RECIPIENT} || "[N/A]";

while (<STDIN>) {
	last if (/^\s*$/);

	$headers .= $_;
	my $ml = $_;

	foreach my $rhl (@required_headers) {
		if ($ml =~ /^$rhl$/) {
			$f = "${f}1";
		}
	}

	if (/^Received:/ && $recvd == 0) {
		$recvd = 1;

		if (/^Received: \(qmail [0-9]{5} invoked by uid 501\); .*$/) {
			$recvd = 2;
		}
	}
}

exit(0) if ((scalar(@required_headers) == length($f)) &&
			($f =~ /1/g) && ($recvd == 2));

if ($dump) {
	my $msg;

	while (<STDIN>) {
		$msg .= $_;
	}

	open(DUMP, ">>$dumpfile") or die "Cannot open file: $dumpfile!";
	my $date = localtime(time);

	print DUMP "AUTOMOD: rejected message from $sndr to $recp ($date)\n";
	print DUMP $headers . "\n" . $msg . "\n\n";

	close(DUMP) or die "Cannot close file: $dumpfile!";
}

print <<EOT;
Message for $recp lacks required header(s). Delivery stopped by $0!
EOT

exit(99);

__END__
