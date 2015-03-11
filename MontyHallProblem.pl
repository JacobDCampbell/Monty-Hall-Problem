#!/usr/bin/perl -w
use strict;

use Getopt::Long;

my (%CONFIG, %GAME);

my %PARAMS = (
    AUTO    => {
        NAME    => 'auto',
        DESC    => 'Boolean.Automate door selections. Initial door selection will always be chnaged unless the --stay option is used.',
        DEFAULT => 0,
    },
    STAY    => {
        NAME    => 'stay',
        DESC    => 'Boolean. Use this option to automatically select to stay with the initial door selection when given the option to change selection.',
        DEFAULT => 0,
    },
    ROUNDS  => {
        NAME    => 'rounds',
        DESC    => 'Number of rounds to play.',
        DEFAULT => 10,
    },
    DOORS   => {
        NAME    => 'doors',
        DESC    => 'Nnumber of doors to start each round with. Minimum value of 3 is required.',
        DEFAULT => 3,
    },
    Z_HELP  => {
        NAME    => 'help',
        DESC    => 'Display usage dialog.',
        DEFAULT => undef(),
    }
);

GetOptions(
	$PARAMS{AUTO}{NAME}         => \$CONFIG{AUTO},
	$PARAMS{STAY}{NAME}         => \$CONFIG{STAY},
	$PARAMS{ROUNDS}{NAME}.':i'  => \$CONFIG{ROUNDS},
	$PARAMS{DOORS}{NAME}.':i'   => \$CONFIG{DOORS},
	$PARAMS{Z_HELP}{NAME}		=> sub { showUsage() },
);

eval { main(); };
die("FATAL ERROR: " . $@) if ($@);

sub main
{
    loadDefaults();
    defineDoors();
	
    for ( my $counter = 0; $counter < $CONFIG{ROUNDS}; $counter++ )
    {
        initRound();
        writeTracker( 'WINNER', setWinningDoor() );
        
        if ( $CONFIG{AUTO} )
        {
            writeTracker( 'FIRST_CHOICE', autoSelectDoor() );
        }
        else
        {
            writeTracker( 'FIRST_CHOICE', userSelectDoor() );
        }
        
        removeDoors();
        
        if ( $CONFIG{STAY} )
        {
            print "Skipping option to change door selection.\n";
            writeTracker( 'SECOND_CHOICE', readTracker( 'FIRST_CHOICE' ) );
        }
        elsif ( $CONFIG{AUTO} )
        {
            writeTracker( 'SECOND_CHOICE', autoSelectDoor() );
        }
        else
        {
            writeTracker( 'SECOND_CHOICE', userSelectDoor() );
        }
        
        if ( readTracker('FIRST_CHOICE') == readTracker('SECOND_CHOICE') )
        {
            writeTracker( 'CHANGED', 1 );
        }
        else
        {
            writeTracker( 'STAYED', 1 );
        }
        
        
        showRoundResults();
        resetDoors();
    }
    
    finalize();
    
    return 1;
}


sub loadDefaults
{
    while ( my ( $key, $details) = each(%PARAMS) )
    {
        next unless ( defined($details->{DEFAULT}) );
        next if ( defined($CONFIG{$key}) );
        $CONFIG{$key} = $details->{DEFAULT};
    }
    
    $CONFIG{DOORS} = 3 if ( $CONFIG{DOORS} < 3 );
}


sub defineDoors
{
    undef(%GAME);
    
    # Set-up doors
    for ( my $i = 1; $i <= $CONFIG{DOORS}; $i++ )
    {
        $GAME{DOORS}{$i} = {
            WINNER      => 0,
            SELECTED    => 0,
            REMOVED     => 0,
        }
    }
    
    return 1;
}


sub initRound
{
    $GAME{ROUND_NUMBER}++;
    print "==> Round: " . $GAME{ROUND_NUMBER} . "\n";
    
    return 1;
}


sub setWinningDoor
{
    my $winner = int( rand( $CONFIG{DOORS} ) ) + 1;
    
    $GAME{DOORS}{$winner}{WINNER} = 1;
    
    return $winner;
}


sub autoSelectDoor
{
    my $selection = int( rand( $CONFIG{DOORS} ) ) + 1;
    
    showDoors();
    while ( $GAME{DOORS}{$selection}{REMOVED} || $GAME{DOORS}{$selection}{SELECTED} )
    {
        $selection = int( rand( $CONFIG{DOORS} ) ) + 1;
    }
    
    print "Selected Door: $selection\n";
    $GAME{DOORS}{$selection}{SELECTED} = 1;
    
    return $selection;
}


sub userSelectDoor
{
    my $selection = undef();
    
    showDoors();
    do
    {
        print "Select Door: ";
        chomp( $selection = <> );
    } while ( ! $GAME{DOORS}{$selection} || $GAME{DOORS}{$selection}{REMOVED} );
    
    #print "Selected Door: $selection\n";
    $GAME{DOORS}{$selection}{SELECTED} = 1;
    
    return $selection;
}


sub showDoors
{
    print "Doors: ";
    foreach my $key ( sort(keys( %{$GAME{DOORS}} )) )
    {
        print " [$key] " unless ( $GAME{DOORS}{$key}{REMOVED} );
    }
    print "\n";
}


sub removeDoors
{
    my $removed = int( rand( $CONFIG{DOORS} ) ) + 1;
    
    for ( my $i = 1; $i <= ($CONFIG{DOORS} - 2); $i++ )
    {
        while ( $GAME{DOORS}{$removed}{WINNER} || $GAME{DOORS}{$removed}{SELECTED} || $GAME{DOORS}{$removed}{REMOVED} )
        {
            $removed = int( rand( $CONFIG{DOORS} ) ) + 1;
        }
        
        print "Removing Door $removed\n";
        $GAME{DOORS}{$removed}{REMOVED} = 1;
    }
    
    return $removed;
}


sub resetDoors
{
    while ( my ($key, $hash) = each( %{$GAME{DOORS}} ) )
    {
        foreach my $key ( keys(%$hash) )
        {
            $$hash{$key} = 0;
        }
    }
}


sub writeTracker
{
    my ( $fieldName, $fieldValue ) = @_;
    my $roundNumber = $GAME{ROUND_NUMBER};
    
    return 0 unless ( defined($fieldName) && defined($fieldValue) );
    
    $GAME{ROUNDS}{$roundNumber}{$fieldName} = $fieldValue;
    
    return 1;
}


sub readTracker
{
    my ( $fieldName, $roundNumber ) = @_;
    $roundNumber = $GAME{ROUND_NUMBER} unless ( defined($roundNumber) );
    
    my $return = $GAME{ROUNDS}{$roundNumber}{$fieldName} || 0;
    
    return $return;
}




sub showRoundResults
{
    my $winner = readTracker( 'WINNER' );
    my $finalChoice = readTracker( 'SECOND_CHOICE' );
    my $result = '';
    if ( $winner == $finalChoice )
    {
        $result = "WINNER!";
        writeTracker( 'WIN', 1 )
    }
    else
    {
        $result = "LOSER!";
        writeTracker( 'WIN', 0 )
    }
    
    print "    Winning Door: " . $winner . "\n";
    print "    Final Selection: " . $finalChoice . "\n";
    print "    $result\n";
    print "\n";
}


sub finalize
{
    my $summaryDetails = parseTrackerData();
    
    my $masterIndexWidth = 30;
    
    print "\n";
    print "  FINAl RESULTS\n";
    for ( my $i = 1; $i <= $masterIndexWidth; $i++ )
    {
        print "=";
    }
    print "\n";
    
    while ( my ($label, $value) = each( %$summaryDetails ) )
    {
        my $localIndexWidth = $masterIndexWidth - length($value);
        print summaryLine($label, $value, $localIndexWidth) . "\n"
    }
    
    return 1;
}


sub parseTrackerData
{
    my $return;
    
    for ( my $roundNum = 1; $roundNum <= $CONFIG{'ROUNDS'}; $roundNum++ )
    {
        my $winningDoor = readTracker( 'WINNER', $roundNum );
        my $firstChoice = readTracker( 'FIRST_CHOICE', $roundNum );
        my $secondChoice = readTracker( 'SECOND_CHOICE', $roundNum );
        
        if ( readTracker( 'WIN', $roundNum ) )
        {
            $return->{'Total Wins'}++;
        }
        else
        {
            $return->{'Total Losses'}++;
        }
    }
    
    return $return;
}


sub summaryLine
{
    my ($label, $value, $lineLength) = @_;
    $lineLength = 30 unless( $lineLength =~ /^\d+$/ );
    
    return 0 unless( $label =~ /^\S+/ && $value =~ /^\S+/ );
    $label = $label . ' ';
    $value = ' ' . $value;
    
    my $minSpace    = 4;
    my $labelLen    = length($label);
    my $valueLen    = length($value);
    my $minLength   = $labelLen + $valueLen + $minSpace;
    $lineLength     = $minLength if ( $lineLength < $minLength );
    
    my $return = $label;
    for ( my $i= $labelLen; $i < ($lineLength - $valueLen); $i++ )
    {
        $return .= '.';
    }
    $return .= $value;
    
    return $return;
}


sub showUsage
{
    foreach my $key ( sort(keys(%PARAMS)) )
    {
        print "Parameter:\t--" . $PARAMS{$key}{NAME} . "\n";
        
        if ( defined($PARAMS{$key}{DEFAULT}) )
        {
            print "Default Value:\t";
            if ( $PARAMS{$key}{DEFAULT} eq 0 )
            {
                print "false\n";
            }
            elsif ( $PARAMS{$key}{DEFAULT} eq 1 )
            {
                print "true\n";
            }
            else
            {
                print $PARAMS{$key}{DEFAULT} . "\n";
            }
        }
        print "Description:\t" . $PARAMS{$key}{DESC} . "\n";
        print "\n";
    }
    
    exit 0;
}
