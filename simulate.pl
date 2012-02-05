#! /usr/bin/perl

# JJ Ford
# Computational Epidemiology
# 04.23.2011

# DEPENDENCIES
#
# Requires the Graph Perl Module (Graph.pm) <http://search.cpan.org/~jhi/Graph-0.94/lib/Graph.pod>
# Requires GraphViz <http://www.graphviz.org/>

# DESCRIPTION
#
# Script will simulate a SLIR (Susceptible, Latent, Infected, Recovered) ODE model using 
# a small population.  The contact between all nodes will be graphed daily and as a total.
# Nodes will contain an ID, graphs will be directed graphs, total graph will be a weighted
# graph.  A .txt data file is also generated so data can be graphed (Excel works great).

# OUTPUT
#
# Graph:
#   Graph Nodes (vertex) Color Codes:
#       - susceptible   : green
#       - latent        : yellow
#       - infected      : red
#       - recovered     : blue
#
#   Nodes(vertex) are labeled with the vertex number followed by the number of contacts in parentheses.
#
#
# Data:
#   data.txt column format will be in the following order:
#       - day number in simulation
#       - number susceptible
#       - number latent
#       - number infected
#       - number recovered

# RULES:
#
# state-state               :   action
#
# susceptible-susceptible   :   no action
# susceptible-latent        :   no action
# susceptible-infected      :   susceptible could become infected
# susceptible-recovered     :   no action
# latent-latent             :   no action
# latent-infected           :   no action
# latent-recovered          :   no action
# infected-infected         :   no action
# infected-recovered        :   no action
#
# After DL days latenet become infected
# After DI days infected become recovered
#
# Edges weighted by number of contacts between two people
#
# Simulation will run until contact limit is reached



# Mode.
use strict;
use warnings;

# Get modules.
use Graph;

# Define constants.
use constant {
    N   => 20,  # Population size
    C   => 5,   # Average number of contacts per person, per day
    TR  => .25, # Transmission rate (hundredths)
    DL  => 3,   # Days latent
    DI  => 4    # Days infectious
};

# Scoping for running in strict environments.
my $author = "JJ Ford";
my $file_handle, my @tv, my @te, my $weight, my $vertex, my $color, my $edge;

# Create regular expresssions (rules).
my $susceptible_infected = qr/susceptible-infected/;
my $infected_susceptible = qr/infected-susceptible/;

# Create graph objects (requires Graph Module).
my $daily_graph = Graph->new;
my $total_graph = Graph->new;

# Initialization.
my $susceptible_count  = N;         # Number susceptible in simulation
my $latent_count       = 0;         # Number latent in simulation
my $infected_count     = 0;         # Number infected in simulation
my $recovered_count    = 0;         # Number recovered in simulation
my $contact_limit      = N * C;     # Total contact limit (population size * avg contacts p/person/day)
my $num_contacts       = 0;         # Total number of contacts in simulation
my $num_days           = 0;         # Number of days in simulation

# Create a buffer to account for the last day of simulation data (0 latent, 0 infected).
my $buffer = 1;

# Set all individuals to susceptible with 0 contacts.
my @person;

for(my $i=0; $i<N; $i++) {
    $person[$i]{state}              = "susceptible";    # Person's state
    $person[$i]{daily_contacts}     = 0;                # Number of contacts made daily
    $person[$i]{total_contacts}     = 0;                # Number of contacts made total
    $person[$i]{dl}                 = 0;                # Days latent count
    $person[$i]{di}                 = 0;                # Days infected count
}

# Set initial simulation state.
# Choose a randome person to infect.
$person[int(rand(N))]{state} = "infected";
$susceptible_count--;
$infected_count++;

# Create outfile directory structure.
mkdir "data";
mkdir "data/dot_files";
mkdir "images";


# Run the simulation.
while( ($latent_count > 0) || ($infected_count > 0) || $buffer) {

    # Scoping for running in strict environments.
    my $instance, my $lottery;
    my @dv, my @de;

    # Manage buffer.
    if( ($latent_count == 0) && ($infected_count == 0) ) {
        $buffer = 0;
    }

    # Simulate population contact.
    while($num_contacts <= $contact_limit) {

        # Randomly select two keys.
        my $key_one = int(rand(N));
        my $key_two = int(rand(N));

        # If the two keys are the same select a new key.
        while ($key_one == $key_two){$key_two = int(rand(N));}

        # Create daily edge and update - vertices will be added implicitly.
        $daily_graph->add_edge($key_one, $key_two);

        # Create total edges - to use weighted edges we must:
        #   - Check if edge exists
        #   - If so get edge weight
        #   - Set new edge weight
        #
        if($total_graph->has_edge($key_one, $key_two)) {
            $weight = $total_graph->get_edge_weight($key_one, $key_two) + 1;
            $total_graph->set_edge_weight($key_one, $key_two, $weight);
        }
        else {
            $total_graph->add_weighted_edge($key_one, $key_two, 1);	
        }

        # Update contact counts.
        $person[$key_one]{daily_contacts}++;
        $person[$key_two]{daily_contacts}++;
        $person[$key_one]{total_contacts}++;
        $person[$key_two]{total_contacts}++;
        $num_contacts += 2;

        # Create instance to test against rules.
        $instance = $person[$key_one]{state} . '-' . $person[$key_two]{state};

        # Run instance against rules
        if($instance =~ $infected_susceptible || $instance =~ $susceptible_infected) {
            $lottery = int(rand(100)) + 1;

            if($lottery <= (TR * 100)) {
                $susceptible_count--;
                $latent_count++;

                if($instance =~ $infected_susceptible) {
                    $person[$key_two]{state} = "latent";
                }
                elsif($instance =~ $susceptible_infected) {
                    $person[$key_one]{state} = "latent";
                }		
            }
        }
    }


    # Create Daily Graph.
    #
    @dv = $daily_graph->vertices;
    @de = $daily_graph->edges;

    # Open a dot file.
    open($file_handle, '>', "data/dot_files/contacts_day_$num_days.dot") or die ("Error: cannot open file\n");

    # Add appropriate comments to the dot file and print the graph information to the file.
    print $file_handle "// Copyright © $author\n";
    print $file_handle "// Day $num_days contacts in SLIR Model\n\n";

    print $file_handle "digraph G {\n";
	
        # Print out each vertex, color coded: 
        #   - susceptible   : green
        #   - latent        : yellow
        #   - infected      : red
        #   - recovered     : blue
        #
        # Nodes are labeled with the vertex number followed by the number of contacts in parentheses.
        #
        for $vertex (@dv) {
            if( $person[$vertex]{state} eq "susceptible") {
                $color="green";
            }
            elsif( $person[$vertex]{state} eq "latent") {
                $color = "yellow";
            }
            elsif( $person[$vertex]{state} eq "infected") {
                $color = "red";
            }
            else {
                $color = "blue";
            }

            print $file_handle "$vertex [label = \"$vertex ($person[$vertex]{daily_contacts})\", color = $color, style = filled, fillcolor = $color];\n";	
        }

        # Print out each edge
        foreach $edge (@de) {	
            print $file_handle "$$edge[0]->$$edge[1];\n";
        }

    print $file_handle "}";

    # External call to Graphviz .
    qx(dot -Tjpg  data/dot_files/contacts_day_$num_days.dot -o images/contacts_day_$num_days.jpg);
    close $file_handle;

    # Create/Append file with SLIR counts
    #
    # Open a txt file
    open($file_handle, '>>', "data/data.txt") or die ("Error: cannot open file\n");
    print $file_handle $num_days ." ". $susceptible_count ." ". $latent_count ." ". $infected_count ." ". $recovered_count ."\n";
    close $file_handle;

    # Simulate Day Change:
    #   - Increment number of days simulation has run
    #   - Increment all latent and infected person counts
    #   - Change person's state if neccessary by rules
    #
    $num_days++;
    for(my $i=0; $i<N; $i++) {
        if($person[$i]{state} eq "infected") {
            $person[$i]{di}++;

            if($person[$i]{di} eq DI) {
                $person[$i]{state} = "recovered";
                $infected_count--;
                $recovered_count++;
            }
        }
        elsif ($person[$i]{state} eq "latent") {
            $person[$i]{dl}++;
			
            if($person[$i]{dl} == DL) {
                $person[$i]{state} = "infected";
                $latent_count--;
                $infected_count++;
            }
        }
    }

    # Reset for next day:
    #	- Number of contacts
    #	- Daily graph
    #	- Daily contacts
    #
    $num_contacts 	= 0;
    $daily_graph 	= Graph->new;
    for(my $i=0; $i<N; $i++) {
        $person[$i]{daily_contacts} = 0;
    }
}


# Create Totals Graph.
#
@tv = $total_graph->vertices;
@te = $total_graph->edges;

# Open a dot file.
open($file_handle, '>', "data/dot_files/contacts_total.dot") or die ("Error: cannot open file\n");

# Add appropriate comments to the dot file and print the graph information to the file
print $file_handle "// Copyright © $author\n";
print $file_handle "// Total contacts in SLIR Model\n\n";

print $file_handle "graph G {\n";

    # Print out each vertex, color coded: 
    #   - susceptible   : green
    #   - latent        : yellow
    #   - infected      : red
    #   - recovered     : blue
    #
    # Nodes are labeled with the vertex number followed by the number of contacts in parentheses
    #
	for $vertex (@tv) {
        if( $person[$vertex]{state} eq "susceptible") {
            $color="green";
        }
        elsif( $person[$vertex]{state} eq "latent") {
            $color = "yellow";
        }
        elsif( $person[$vertex]{state} eq "infected") {
            $color = "red";
        }
        else {
            $color = "blue";
        }

        print $file_handle "$vertex [label = \"$vertex ($person[$vertex]{total_contacts})\", color = $color, style = filled, fillcolor = $color];\n";	
    }
	
    # Print out each edge
    foreach $edge (@te) {
        $weight = $total_graph->get_edge_weight($$edge[0], $$edge[1]);
        print $file_handle "$$edge[0]--$$edge[1] [weight = $weight];\n";
    }
	
print $file_handle "}";

# External call to Graphviz 
qx(dot -Tjpg  data/dot_files/contacts_total.dot -o images/contacts_total.jpg);
close $file_handle;

# End of program.