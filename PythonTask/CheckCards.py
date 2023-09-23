import re

num_of_cards = int(input())

cards = []
for i in range(num_of_cards):
    cards.append(input())
    
def check_for_consequtives(card, isHyphenSeparated=False):
    if isHyphenSeparated:
        card = "".join(card.split("-"))
        
    same_char_count = 1
    for i in range(1, len(card)):
        if card[i-1] == card[i]:
            same_char_count += 1
        else:
            same_char_count = 1
        
        if same_char_count == 4:
            return False
    return True
    
for card in cards:
    if re.match("^[456]{1}[0-9]{15}$", card):
        # Check for consequtives
        if check_for_consequtives(card):
            print("Valid")
        else:
            print("Invalid")
    elif re.match("^[456]{1}[0-9]{3}-[0-9]{4}-[0-9]{4}-[0-9]{4}$", card):
        # check for consequtives
        if check_for_consequtives(card, True):
            print("Valid")
        else:
            print("Invalid")
    else:
        print("Invalid")    
    