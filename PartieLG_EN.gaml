/**
* Name: WerewolfModel
* ModelWerewolf 
* Author: Va - Ma
* Tags: 
*/


model werewolf

global {
    string phase <- "NIGHT";
    bool game_done <- false;
    
    // Game initialization
    init {
    	int nb_ww <- 4;
    	int nb_vil <- 9;
    	int nb_see <- 1;
    	int nb_wit <- 0;
    	int total <- nb_ww + nb_vil + nb_see + nb_wit;
        create Werewolf number: nb_ww { location <- any_location_in(world); }
        loop i over: Werewolf{
        	ask Werewolf { if (self != i) { self.relations[i] <- 1; } }
        }
        create Seer number: nb_see { location <- any_location_in(world); }
        create Villager number: nb_vil { location <- any_location_in(world); }
        create Witch number: nb_wit {location <- any_location_in(world); }
        write "--- GAME INITIALIZED ("+ total + " Players) ---";
    }
    
    // General functions
    
     action start_debate(list<player> live_village){
        player accuser <- one_of(live_village);
        player accused <- accuser.most_disliked(live_village - accuser);
        
        write "---Debate between "+ accuser + " and " + accused + " ---";
        
        float strength_charge <- accuser.charisma * rnd(0.8, 1.2); //On top of the eloquence, we add a scaler on the strength of the argument
        float strength_defense <- accused.charisma * rnd(0.8, 1.2);
        
        ask live_village - accuser - accused {
        	if (flip(0.25)){//We'll say there's a 1/4 chance that one gets "moved" by the debate, not too dissimilar to how it goes in a real game
	        	//We take into account the previous relationship between both the accuser and accused, and the player.
	        	float weight_cha <- strength_charge + self.relations[accuser]; 
	        	float weight_def <- strength_defense + self.relations[accused];
	        	
	        	if (weight_cha > weight_def){// If the accused is less convincing from the player's point of view
	        		relations[accuser] <- relations[accuser] + 0.1; // We increase trust with the accuser
	        		relations[accused] <- relations[accused] - 0.1;	// And the accused becomes less trustworthy
	        	}else{ //Otherwise we do the opposite
	        		relations[accuser] <- relations[accuser] - 0.1;
	        		relations[accused] <- relations[accused] + 0.1;	
	        		}
        		}
        	}
        }
    
    player highest_voted(list<player> target) {
        int highest <- 0;
        list<player> tiebreak <- []; // List made to handle vote equalities
        
        ask target { if (self.target_counter > highest) {highest <- self.target_counter; tiebreak <- []; add self to: tiebreak;} 
        	else if (self.target_counter = highest) { add self to: tiebreak; }
        }
        
        return one_of(tiebreak); // In this, we decide to take someone at random amongst the equally highest voted.
    }

	// How the game goes, if not finished
    reflex game_loop when: !game_done {
    	// Night starts
        if (phase = "NIGHT") {
            write " --- Night starts ---";
            // During the night, we start with the werewolves
            
            list<Werewolf> live_wolves <- [];
            ask Werewolf { if (self.is_alive) { add self to: live_wolves; } }
            list<player> in_danger <- []; // Exists because of roles that can protect/ressucitate players
            
            if (length(live_wolves) > 0) {
            	list<player> possibles_prey <- [];
		        ask Seer { if (self.is_alive) { add self to: possibles_prey;} }
		        ask Villager { if (self.is_alive) { add self to: possibles_prey; } }
		        ask Witch {if (self.is_alive) {add self to: possibles_prey; } }
                ask live_wolves {
                    do execute(s: self, prey: possibles_prey);
                }
                add one_of(highest_voted(possibles_prey)) to: in_danger;
            }
            
            list<player> live_village <- [];
            ask Werewolf { if (self.is_alive) { add self to: live_village; } }
            ask Seer { if (self.is_alive) { add self to: live_village; } }
            ask Villager { if (self.is_alive) { add self to: live_village; } }
            ask Witch { if (self.is_alive) { add self to: live_village; } }
            
            // Next, the witch's turn
            ask Witch {
            	if self.is_alive{
            		do execute(s: self, id: in_danger, lv: live_village);
            		}
            }
            
         	// Next, the seer's turn
            ask Seer {
            	if self.is_alive {
            		do execute(s: self);
            		}
            }
            
			// At the end of the night, we announce the victims, and proceed to the day
			if (not empty(in_danger)) {
				loop i over: in_danger{
				i.is_alive <- false;
				write "" + i + " has been eliminated.";
				}
			}
			else { write "No one died tonight";}
            phase <- "DAY";
            
        // Day starts
        } else if (phase = "DAY") {
            write "--- Day starts ---";
            
          	// We'll ask every person alive to vote
            list<player> live_village <- [];
            list<player> WW_List <- [];
            list<player> non_Werewolf <- [];
            map <player, player> votes <-[];
            ask Werewolf { if (self.is_alive) { self.target_counter <- 0; add self to: live_village; add self to: WW_List; } }
            ask Seer { if (self.is_alive) { self.target_counter <- 0; add self to: live_village; add self to: non_Werewolf; } }
            ask Villager { if (self.is_alive) { self.target_counter <- 0; add self to: live_village; add self to: non_Werewolf; } }
            ask Witch { if (self.is_alive) { self.target_counter <- 0; add self to: live_village; add self to: non_Werewolf; } }
            
            if (length(live_village) > 2) { // We start the debate
            		do start_debate(live_village);
		            ask WW_List {
            		player k <- most_disliked(live_village - self);
            		write "" + self + " voted for " + k;
            		do village_vote(k);
            		votes[self] <- k;
            	}
            	ask non_Werewolf {
            		player k <- most_disliked(live_village - self);
            		write "" + self + " voted for " + k;
            		do village_vote(k);
            		votes[self] <- k;
            	}
                player victim <- highest_voted(live_village);
                victim.is_alive <- false;
                write "The village voted out : " + victim;
                
                list<player> right_votes <- []; //List of players that voted for the victim
                map<player, player> other_votes <- [];
            	loop j over: keys(votes) {
            		if (votes[j] = victim) {
            			add j to: right_votes;
            		}else{
            			other_votes[j] <- votes[j];
            		}
				}
				 ask live_village {
				 	loop j over: other_votes{
				 		if (other_votes[j] = self){ // If someone voted for us, we lose some trust in them in general
				 			relations[j] <- relations[j] - 0.1;
				 		}
				 	}
				 	if (victim is Werewolf) {
				 		loop b over: right_votes {
				 			if (self is Werewolf){ //If the victim was a werewolf, then the village trusts people who voted them out more, as opposed to the werewolves who see the right voters as more of a threat
				 				relations[b] <- relations[b] - 0.2;
				 			}else{
				 				relations[b] <- relations[b] + 0.2;
				 			}
       			 		}
   					}   	
                }
            }
            // At the end of the day, night starts again
            phase <- "NIGHT";
        }
        
        // We check if the game ended
        int nb_wolves <- 0;
        ask Werewolf { if (self.is_alive) { nb_wolves <- nb_wolves + 1; } }
        
        int nb_others <- 0;
        // We tally up other species seperately because of a bug of unknown source
        ask Seer { if (self.is_alive) { nb_others <- nb_others + 1; } }
        ask Villager { if (self.is_alive) { nb_others <- nb_others + 1; } }
        ask Witch {if (self.is_alive) {nb_others <- nb_others + 1; } }
        
        // If no wolf remains, villagers win, and the game ends.
        if (nb_wolves = 0) {
            write "VILLAGERS WIN !";
            game_done <- true;
            do pause; 
        // If there's at least as many wolves as there are villagers, wolves win and the game ends.
        } else if (nb_wolves >= nb_others) {
            write "WEREWOLVES WIN !";
            game_done <- true;
           	do pause;
        } else {
            // Otherwise, the game continues.
            do pause;
        }
    }
}

// Definition of the Player class
species player {
    bool is_alive <- true;
    rgb color <- #gray;
    int target_counter <- 0;
    int vote_value <- 1;
    float charisma <- rnd(0.5, 1.5);
    map<agent, float> relations <- [];
    
    reflex init_relations when: empty(relations){
    	ask player { if (self != myself) { relations[self] <- 0.0; }
    		else { relations[self] <- 10; }
    	}
    }
    
    action village_vote(player s){
    	s.target_counter <- s.target_counter + vote_value;
    }
    
    player most_disliked(list<player> v){
    	float dislike <- self.relations[v[0]];
    	list<player> tiebreaker;
    	add v[0] to: tiebreaker;
    	loop j over: v{
    		if (self.relations[j] < dislike) { tiebreaker <- []; add j to: tiebreaker; dislike <- self.relations[j];}
    		else if (self.relations[j] = dislike) {add j to: tiebreaker;}
    	}
    	return one_of(tiebreaker);
    }
    
    player most_liked(list<player> v){
    	float like <- self.relations[v[0]];
    	list<player> tiebreaker;
    	add v[0] to: tiebreaker;
    	loop j over: v{
    		if (self.relations[j] > like) { tiebreaker <- []; add j to: tiebreaker; like <- self.relations[j];}
    		else if (self.relations[j] = like) {add j to: tiebreaker;}
    	}
    	return one_of(tiebreaker);
    }
    
    aspect base {
        if (is_alive) {
            draw circle(2) color: color;
        } else {
            draw cross(2, 0.5) color: #red;
        }
    }
}


// Definition of the Werewolf class
species Werewolf parent: player{
    rgb color <- #black;
    float charisma <- charisma + 0.3; // We make the assumption that, as a Werewolf usually needs to hide his nature, he develops a bigger talent towards fooling/convincing others
    
    // We define the voting against a player
    action vote_night(player target) {
        target.target_counter <- target.target_counter + 1;
    }
	
	// And the act of choosing a target
    action execute(player s, list<player> prey) {
        // The wolves only target villagers and the seer, but we put the possible prey directly in the game loop because every wolf uses these
        if (flip(0.2)) {
        	//In 20% of cases, the Werewolf votes for the player they dislike most
        	player current_prey <- most_disliked(prey);
        	do vote_night(current_prey);
        } else {
        do vote_night(one_of(prey)); // Else they vote at random
        }
       
    }    
}

// Definition of the Seer class
species Seer parent: player {
    rgb color <- #purple;
    list<player> known_players<- [];
    
    action see(player target) {
        write "The seer discovered the role of : " + target; // Obviously this doesn't impact other entities in game, and is just a clarification for the spectator of the game
        add target to: known_players;
    }
    
	// Definition of how the action is executed
    action execute(player s) {
        list<player> possible_targets <- [];
        ask Werewolf { if (self.is_alive) { add self to: possible_targets; } }
        ask Villager { if (self.is_alive) { add self to: possible_targets; } }
        
        possible_targets <- possible_targets - known_players;
        
        if (length(possible_targets) > 0) {
        	player target <- one_of(possible_targets);
            do see(target);
            if (Werewolf contains target) {relations[target] <- -5;} // So that there can be an order, but the Seer will "always" prioritize voting a Werewolf if possible
            else {relations[target] <- 3;} // If a player isn't a Werewolf, we'll pretty much never vote them
        }
        else {
        	write "The seer has uncovered the identities of everyone.";
        }
    }
}

// Definition of the Witch class
species Witch parent: player {
    rgb color <- #red;
    bool health_pot <- true;
    bool death_pot <- true;
    
    // Definition of the poison action
    action poison(list<player> lv) {
        player to_kill <- most_disliked(lv);
    	if (relations[to_kill] <= -0.2){ // So that the Witch doesn't just throw the potion at random, rather on someone they already has doubts.
    		to_kill.is_alive <- false;
    		remove to_kill from: lv;
    		//write "Witch killed "  + to_kill; // Can be added back if we want to see even more details of the game, but usually we don't know.
    		write "" + to_kill + " has been eliminated.";
    		death_pot <- false;
    	}
    }
    
    // Definition of the save action
    action save(list<player> id) {
    	player to_save <- most_liked(id);
    	if (relations[to_save] >= 0.2){ // So that the Witch doesn't just throw the potion at random, rather on someone they already trust.
    		remove to_save from: id;
    		//write "Witch saved "  + to_save; // Can be added back if we want to see even more details of the game, but usually we don't know.
    		health_pot <- false;
    	}
    }
    
	// Definition of how the action is executed
    action execute(player s, list<player> id, list<player> lv) {
        if (health_pot){ // A witch only has one health potion
        	do save(id);
        }
        if (death_pot){ // A witch only has one death potion
        	do poison(lv);
        }
    }
}

// Definition of the Villager class
species Villager parent: player {
    rgb color <- #green;
}


// Definition of the environment
experiment "Werewolf Simulation" type: gui {
    output {
        display "Village" {
            species Werewolf aspect: base;
            species Seer aspect: base;
            species Villager aspect: base;
            species Witch aspect: base;
        }
    }
}