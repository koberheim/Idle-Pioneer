# Colony names

**Approved and in use** (`data/colony_names.json`). The file has the same keys (`english`, `french`, `spanish`, `dutch`, `portuguese`, `swedish`) and 25 strings per nation. Index 0 is the capital. Nothing in the game code needs to change.

## Naming convention

**Each name uses the form the colonists themselves used, in their own language, written in that language's standard spelling with its accents.** Examples: Québec, Trois-Rivières, La Nouvelle-Orléans, La Habana, San Agustín, Nieuw Amsterdam, Breuckelen, Fort Nya Elfsborg, Mölndal, São João. English names use the period English name (Charles Town, not Charleston).

Why this convention:
- The game is about the colonists, so their own names fit it best. It also fixes the audit's complaint about mixed English and native forms (for example "Havana" next to "Santiago de los Caballeros").
- A single rule per nation removes the accent inconsistency. The current French list writes "Quebec" but also "Trois-Rivieres".
- Both game fonts can display every accent used here. I checked `assets/fonts/Almendra-Regular.ttf` and `LibreBaskerville-Regular.ttf` for é è ê ç ã õ á í ó ú ñ ö å ä â ô û, and none is missing.
- When a period spelling varied, the proposal uses the best-attested form and puts the other forms in Notes.

Other rules applied:
- **Order.** The capital comes first. The other 24 follow in order of founding (or first record), so a run replays the nation's history. For France, the capital Québec (1608) comes before three older sites.
- **Map area.** Every name lies between Labrador/Hudson Bay and Panama, including the Caribbean. Nothing comes from South America or the Pacific coast. Borderline names are marked **borderline**.
- **Length.** Every name is 22 characters or fewer. The longest are Concepción de la Vega and Puebla de los Ángeles, at 21 each.
- **No clashes.** No name appears in two lists. The ambiguous names the audit flagged (St. John's, Charlestown, and the English Port Royal) are gone. Port-Royal is now only French.
- **Dates.** "c." marks an uncertain or approximate date. Where the name came later than the founding, both are given.

## Decisions for the owner

1. **England capital: Jamestown (1607)**, as proposed. It was the first permanent English settlement in the Americas. St. John's is rejected for three reasons: it was a seasonal fishing harbour with no founding act, the name is ambiguous, and the name first appears on a *Portuguese* chart (1519). Cuper's Cove (1610) is #2. The alternative is Cuper's Cove as capital.
2. **France capital: Québec (1608)**, as proposed. It was the seat of New France. Port-Royal (1605) is older but was abandoned in 1613, and it is #4 here. The alternative is to use Port-Royal as capital and keep a strict date order.
3. **Spain capital: Santo Domingo (1496/98)**, as proposed. It was the first lasting European city in the Americas and the seat of the first Audiencia. The alternative is San Agustín (1565), the first permanent European city in what is now the USA, if you want a "North America" feel. It is #20 here.
4. **Netherlands capital: Nieuw Amsterdam (1625)**, as proposed. Fort Oranje (1624) is a little older and is #3. Fort Nassau (1614) is #2.
5. **Portugal: the weakest nation.** Portugal founded no lasting settlement anywhere on this map. The proposal uses 16 real Portuguese place names that its fishermen and explorers gave (harbours, capes and islands of Newfoundland, plus Barbados, which is a Portuguese name). These are followed by **9 invented names in period style**, each clearly marked. Options:
   (a) Accept this list.
   (b) Swap Portugal for **Denmark–Norway**, which had real Caribbean colonies: Charlotte Amalie, Christiansted, Frederiksted, Christiansværn and others. Enough real names would need Danish Greenland, which is off the map.
   (c) Keep Portugal but add a code fallback, so that tiers 17–25 show generic "Colony N" labels instead of invented names.
   I recommend (a) for now, and (b) if a 25-real-names standard matters more than having Portugal.
6. **Sweden has 0 invented names, but 3 are weak.** New Sweden alone gives 21 real Swedish place names. **Wicaco** (#22) is a Lenape name used by the Swedish community after 1655, under English rule. **Fort Gustaf** and **Fort Carl** (#24–25) are the Swedish forts at Gustavia on Saint-Barthélemy, and their build dates are uncertain. You can replace any of these with invented Swedish names such as "Nya Kalmar" or "Nya Wästerås".
7. **Borderline locations.** Please confirm each is on the map:
   - Willemstad, Curaçao: 12.1°N, south edge.
   - Nieuw Walcheren, Tobago: 11.2°N 60.7°W, south-east corner.
   - Santa Fe and Alburquerque: about 106°W, at the Rockies, west edge.
   - Nombre de Dios and Portobelo: Caribbean coast of Panama, about 9.5°N.
   - Guadalajara and Zacatecas: inland western Mexico.
   - York Factory and Moose Factory: Hudson Bay/James Bay, north edge. These should be inside.
8. **Spelling choices you might prefer differently:**
   - Plymouth or *Plimoth* (Bradford's spelling).
   - Montréal or *Ville-Marie* (its 1642 founding name).
   - Cap-Français or *Cap-François* (the 17th-century form).
   - Fort Nya Götheborg or *Nya Göteborg* (modern spelling).
   - Pittsburgh or *Pittsborough* (Forbes, 1758).

---

## England (`english`)

| # | Name | Founded | Location today | Notes | Source |
|---|------|---------|----------------|-------|--------|
| 1 | Jamestown | 1607 | Virginia, USA | **capital**; first permanent English settlement in the Americas | [Wikipedia: Jamestown](https://en.wikipedia.org/wiki/Jamestown,_Virginia) |
| 2 | Cuper's Cove | 1610 | Cupids, Newfoundland | first English colony in Newfoundland (John Guy) | [Wikipedia: Cupids](https://en.wikipedia.org/wiki/Cupids,_Newfoundland_and_Labrador) |
| 3 | Henricus | 1611 | Chesterfield Co., Virginia | "Citie of Henricus", Thomas Dale | [Wikipedia: Henricus](https://en.wikipedia.org/wiki/Henricus) |
| 4 | Plymouth | 1620 | Massachusetts, USA | Pilgrim colony; also spelled *Plimoth* | [Wikipedia: Plymouth Colony](https://en.wikipedia.org/wiki/Plymouth_Colony) |
| 5 | Ferryland | 1621 | Newfoundland | Calvert's Colony of Avalon | [Wikipedia: Ferryland](https://en.wikipedia.org/wiki/Ferryland) |
| 6 | Old Road | 1624 | St. Kitts | Thomas Warner's first English Caribbean settlement | [Wikipedia: Old Road Town](https://en.wikipedia.org/wiki/Old_Road_Town) |
| 7 | Salem | 1626 | Massachusetts, USA | Roger Conant (Naumkeag); named Salem 1629 | [Wikipedia: Salem](https://en.wikipedia.org/wiki/Salem,_Massachusetts) |
| 8 | Bridgetown | 1628 | Barbados | "the Indian Bridge"; later St. Michael's Town | [Wikipedia: Bridgetown](https://en.wikipedia.org/wiki/Bridgetown) |
| 9 | Boston | 1630 | Massachusetts, USA | Massachusetts Bay Colony | [Wikipedia: Boston](https://en.wikipedia.org/wiki/History_of_Boston) |
| 10 | St. Mary's City | 1634 | Maryland, USA | first capital of Maryland | [Wikipedia: St. Mary's City](https://en.wikipedia.org/wiki/St._Mary%27s_City,_Maryland) |
| 11 | Hartford | c. 1635 | Connecticut, USA | settled as Newtown 1635–36; named Hartford 1637 | [Wikipedia: Hartford](https://en.wikipedia.org/wiki/Hartford,_Connecticut) |
| 12 | Providence | 1636 | Rhode Island, USA | Roger Williams | [Wikipedia: Providence](https://en.wikipedia.org/wiki/Providence,_Rhode_Island) |
| 13 | New Haven | 1638 | Connecticut, USA | Quinnipiac; named New Haven 1640 | [Wikipedia: New Haven Colony](https://en.wikipedia.org/wiki/New_Haven_Colony) |
| 14 | Charles Town | 1670 | Charleston, South Carolina | period name (Charleston from 1783) | [Wikipedia: Charleston](https://en.wikipedia.org/wiki/Charleston,_South_Carolina) |
| 15 | Moose Factory | c. 1673 | Ontario (James Bay) | Hudson's Bay Company post ("Moose Fort") | [Wikipedia: Moose Factory](https://en.wikipedia.org/wiki/Moose_Factory) |
| 16 | Philadelphia | 1682 | Pennsylvania, USA | William Penn | [Wikipedia: Philadelphia](https://en.wikipedia.org/wiki/History_of_Philadelphia) |
| 17 | York Factory | 1684 | Manitoba (Hudson Bay) | HBC trading post; north edge | [Wikipedia: York Factory](https://en.wikipedia.org/wiki/York_Factory) |
| 18 | Kingston | 1692 | Jamaica | founded after the Port Royal earthquake | [Wikipedia: Kingston](https://en.wikipedia.org/wiki/Kingston,_Jamaica) |
| 19 | Annapolis | c. 1694 | Maryland, USA | settled 1649 as Providence; new capital, Annapolis from 1695 | [Wikipedia: Annapolis](https://en.wikipedia.org/wiki/Annapolis,_Maryland) |
| 20 | Williamsburg | 1699 | Virginia, USA | Middle Plantation renamed as new capital | [Wikipedia: Williamsburg](https://en.wikipedia.org/wiki/Williamsburg,_Virginia) |
| 21 | Baltimore | 1729 | Maryland, USA | Baltimore Town | [Wikipedia: Baltimore](https://en.wikipedia.org/wiki/History_of_Baltimore) |
| 22 | Savannah | 1733 | Georgia, USA | Oglethorpe | [Wikipedia: Savannah](https://en.wikipedia.org/wiki/Savannah,_Georgia) |
| 23 | Frederica | 1736 | St. Simons Island, Georgia | fortified town, Oglethorpe | [Wikipedia: Fort Frederica](https://en.wikipedia.org/wiki/Fort_Frederica_National_Monument) |
| 24 | Halifax | 1749 | Nova Scotia | Cornwallis | [Wikipedia: Halifax](https://en.wikipedia.org/wiki/History_of_Halifax,_Nova_Scotia) |
| 25 | Pittsburgh | 1758 | Pennsylvania, USA | named by Forbes on the site of Fort Duquesne (period spelling also *Pittsborough*) | [Wikipedia: Pittsburgh](https://en.wikipedia.org/wiki/History_of_Pittsburgh) |

**Changes from the current list:**
- Removed:
  - St. John's, Charlestown and Port Royal (ambiguous).
  - St. George's (Bermuda, off the map).
  - Sandy Point Town (replaced by Old Road, Warner's actual first site).
  - New York (captured from the Dutch, not founded by the English).
  - Charleston (replaced by the period form Charles Town).
- Added: Ferryland, Old Road, Moose Factory, York Factory, Frederica, Pittsburgh.
- Capital changed from St. John's to Jamestown.
- Invented: 0.

## France (`french`)

| # | Name | Founded | Location today | Notes | Source |
|---|------|---------|----------------|-------|--------|
| 1 | Québec | 1608 | Quebec City | **capital** of New France (Champlain); out of date order because it is the capital | [Wikipedia: Quebec City](https://en.wikipedia.org/wiki/History_of_Quebec_City) |
| 2 | La Caroline | 1564 | Jacksonville, Florida | Huguenot "Fort de la Caroline"; destroyed 1565 | [Wikipedia: Fort Caroline](https://en.wikipedia.org/wiki/Fort_Caroline) |
| 3 | Tadoussac | 1600 | Quebec | trading post (Chauvin); the name is Innu, and it is used here as the French post's name | [Wikipedia: Tadoussac](https://en.wikipedia.org/wiki/Tadoussac) |
| 4 | Port-Royal | 1605 | Annapolis Royal area, Nova Scotia | Habitation of Port-Royal (de Mons, Champlain) | [Wikipedia: Port-Royal](https://en.wikipedia.org/wiki/Port-Royal_(Acadia)) |
| 5 | Trois-Rivières | 1634 | Quebec | Laviolette | [Wikipedia: Trois-Rivières](https://en.wikipedia.org/wiki/Trois-Rivi%C3%A8res) |
| 6 | Saint-Pierre | 1635 | Martinique | d'Esnambuc; first French town on Martinique | [Wikipedia: Saint-Pierre](https://en.wikipedia.org/wiki/Saint-Pierre,_Martinique) |
| 7 | Montréal | 1642 | Montreal | founded as Ville-Marie (Maisonneuve) | [Wikipedia: Montreal](https://en.wikipedia.org/wiki/History_of_Montreal) |
| 8 | Basse-Terre | c. 1643 | Guadeloupe | Fort Saint-Charles built 1650 | [Wikipedia: Basse-Terre](https://en.wikipedia.org/wiki/Basse-Terre) |
| 9 | Plaisance | 1662 | Placentia, Newfoundland | French colonial capital of Newfoundland | [Wikipedia: Plaisance](https://en.wikipedia.org/wiki/Plaisance,_Newfoundland) |
| 10 | Fort-Royal | c. 1669 | Fort-de-France, Martinique | town laid out under de Baas | [Wikipedia: Fort-de-France](https://en.wikipedia.org/wiki/Fort-de-France) |
| 11 | Cap-Français | 1670 | Cap-Haïtien, Haiti | also written *Cap-François* | [Wikipedia: Cap-Haïtien](https://en.wikipedia.org/wiki/Cap-Ha%C3%AFtien) |
| 12 | Fort Frontenac | 1673 | Kingston, Ontario | fort and trading post | [Wikipedia: Fort Frontenac](https://en.wikipedia.org/wiki/Fort_Frontenac) |
| 13 | Grand-Pré | 1682 | Nova Scotia | Acadian village | [Wikipedia: Grand-Pré](https://en.wikipedia.org/wiki/Grand-Pr%C3%A9,_Nova_Scotia) |
| 14 | Fort Maurepas | 1699 | Ocean Springs, Mississippi | first French post in Louisiana (Iberville); replaces "Biloxi" | [Wikipedia: Fort Maurepas](https://en.wikipedia.org/wiki/Fort_Maurepas) |
| 15 | Détroit | 1701 | Detroit, Michigan | Fort Pontchartrain du Détroit (Cadillac) | [Wikipedia: Detroit](https://en.wikipedia.org/wiki/History_of_Detroit) |
| 16 | La Mobile | 1702 | Mobile, Alabama | Fort Louis de la Mobile | [Wikipedia: Mobile](https://en.wikipedia.org/wiki/History_of_Mobile,_Alabama) |
| 17 | Kaskaskia | 1703 | Illinois, USA | Jesuit mission village; Illinois Country | [Wikipedia: Kaskaskia](https://en.wikipedia.org/wiki/Kaskaskia,_Illinois) |
| 18 | Louisbourg | 1713 | Cape Breton, Nova Scotia | fortress town | [Wikipedia: Louisbourg](https://en.wikipedia.org/wiki/Fortress_of_Louisbourg) |
| 19 | Natchitoches | 1714 | Louisiana, USA | Saint-Denis; the name is Caddo, and it is used here as the French post's name | [Wikipedia: Natchitoches](https://en.wikipedia.org/wiki/Natchitoches,_Louisiana) |
| 20 | Fort Rosalie | 1716 | Natchez, Mississippi | Bienville | [Wikipedia: Fort Rosalie](https://en.wikipedia.org/wiki/Fort_Rosalie) |
| 21 | La Nouvelle-Orléans | 1718 | New Orleans | Bienville; 19 characters | [Wikipedia: New Orleans](https://en.wikipedia.org/wiki/History_of_New_Orleans) |
| 22 | Vincennes | 1732 | Indiana, USA | Poste Vincennes | [Wikipedia: Vincennes](https://en.wikipedia.org/wiki/Vincennes,_Indiana) |
| 23 | Port-au-Prince | 1749 | Haiti | new capital of Saint-Domingue | [Wikipedia: Port-au-Prince](https://en.wikipedia.org/wiki/Port-au-Prince) |
| 24 | Fort Duquesne | 1754 | Pittsburgh, Pennsylvania | Forks of the Ohio | [Wikipedia: Fort Duquesne](https://en.wikipedia.org/wiki/Fort_Duquesne) |
| 25 | Saint-Louis | 1764 | St. Louis, Missouri | founded by French traders (Laclède, Chouteau); Louisiana had already been ceded to Spain in secret | [Wikipedia: St. Louis](https://en.wikipedia.org/wiki/History_of_St._Louis) |

**Changes from the current list:**
- Accents restored throughout: Québec, Trois-Rivières, Montréal, Cap-Français, Grand-Pré.
- Period forms used: La Caroline, La Mobile, La Nouvelle-Orléans, Saint-Louis.
- Removed:
  - Cayenne (South America, off the map).
  - Baton Rouge (date and founding uncertain).
- Replaced Biloxi with Fort Maurepas.
- Added: Saint-Pierre, Fort Rosalie.
- Capital changed from Fort Caroline to Québec.
- Invented: 0.

## Spain (`spanish`)

| # | Name | Founded | Location today | Notes | Source |
|---|------|---------|----------------|-------|--------|
| 1 | Santo Domingo | 1496/98 | Dominican Republic | **capital**; oldest lasting European city in the Americas; seat of the first Audiencia | [Wikipedia: Santo Domingo](https://en.wikipedia.org/wiki/Santo_Domingo) |
| 2 | La Isabela | 1494 | Dominican Republic | Columbus; abandoned c. 1498 | [Wikipedia: La Isabela](https://en.wikipedia.org/wiki/La_Isabela) |
| 3 | Concepción de la Vega | c. 1494/95 | La Vega, Dominican Republic | fortress, then town; 21 characters | [Wikipedia: Concepción de la Vega](https://en.wikipedia.org/wiki/Concepci%C3%B3n_de_la_Vega) |
| 4 | Caparra | 1508 | near San Juan, Puerto Rico | Ponce de León; moved to San Juan 1521 | [Wikipedia: Caparra](https://en.wikipedia.org/wiki/Caparra_Archaeological_Site) |
| 5 | Nombre de Dios | 1510 | Colón province, Panama | Caribbean coast; south edge | [Wikipedia: Nombre de Dios](https://en.wikipedia.org/wiki/Nombre_de_Dios,_Col%C3%B3n) |
| 6 | Baracoa | 1511 | Cuba | first Spanish town in Cuba (Velázquez) | [Wikipedia: Baracoa](https://en.wikipedia.org/wiki/Baracoa) |
| 7 | Bayamo | 1513 | Cuba | | [Wikipedia: Bayamo](https://en.wikipedia.org/wiki/Bayamo) |
| 8 | Trinidad | 1514 | Cuba | Villa de la Santísima Trinidad | [Wikipedia: Trinidad, Cuba](https://en.wikipedia.org/wiki/Trinidad,_Cuba) |
| 9 | Santiago de Cuba | 1515 | Cuba | | [Wikipedia: Santiago de Cuba](https://en.wikipedia.org/wiki/Santiago_de_Cuba) |
| 10 | Vera Cruz | 1519 | Veracruz, Mexico | Villa Rica de la Vera Cruz (Cortés); spelled as two words in the period | [Wikipedia: Veracruz](https://en.wikipedia.org/wiki/Veracruz,_Veracruz) |
| 11 | La Habana | 1519 | Havana, Cuba | San Cristóbal de La Habana; first founded 1514, moved to the present site 1519 | [Wikipedia: Havana](https://en.wikipedia.org/wiki/History_of_Havana) |
| 12 | Granada | 1524 | Nicaragua | Hernández de Córdoba | [Wikipedia: Granada](https://en.wikipedia.org/wiki/Granada,_Nicaragua) |
| 13 | León | 1524 | León Viejo, Nicaragua | | [Wikipedia: León Viejo](https://en.wikipedia.org/wiki/Le%C3%B3n_Viejo) |
| 14 | San Salvador | 1525 | El Salvador | refounded 1528 | [Wikipedia: San Salvador](https://en.wikipedia.org/wiki/San_Salvador) |
| 15 | Puebla de los Ángeles | 1531 | Puebla, Mexico | new Spanish city, not an older town renamed; 21 characters | [Wikipedia: Puebla](https://en.wikipedia.org/wiki/Puebla_(city)) |
| 16 | Campeche | 1540 | Mexico | San Francisco de Campeche | [Wikipedia: Campeche](https://en.wikipedia.org/wiki/San_Francisco_de_Campeche) |
| 17 | Mérida | 1542 | Yucatán, Mexico | built on the site of the Maya city T'ho | [Wikipedia: Mérida](https://en.wikipedia.org/wiki/M%C3%A9rida,_Yucat%C3%A1n) |
| 18 | Guadalajara | 1542 | Jalisco, Mexico | fourth and final site; inland west, near the edge | [Wikipedia: Guadalajara](https://en.wikipedia.org/wiki/Guadalajara) |
| 19 | Zacatecas | 1546 | Mexico | silver town | [Wikipedia: Zacatecas](https://en.wikipedia.org/wiki/Zacatecas_City) |
| 20 | San Agustín | 1565 | St. Augustine, Florida | Menéndez de Avilés; oldest continuous European city in the USA (possible capital) | [Wikipedia: St. Augustine](https://en.wikipedia.org/wiki/St._Augustine,_Florida) |
| 21 | Portobelo | 1597 | Colón province, Panama | San Felipe de Portobelo; south edge | [Wikipedia: Portobelo](https://en.wikipedia.org/wiki/Portobelo,_Col%C3%B3n) |
| 22 | Santa Fe | 1610 | New Mexico, USA | La Villa Real de la Santa Fe; **borderline**: west edge | [Wikipedia: Santa Fe](https://en.wikipedia.org/wiki/Santa_Fe,_New_Mexico) |
| 23 | Santa María de Galve | 1698 | Pensacola, Florida | period name of the Pensacola presidio | [Wikipedia: Pensacola](https://en.wikipedia.org/wiki/History_of_Pensacola,_Florida) |
| 24 | Alburquerque | 1706 | Albuquerque, New Mexico | period spelling, after the Duke of Alburquerque; **borderline**: west edge | [Wikipedia: Albuquerque](https://en.wikipedia.org/wiki/Albuquerque,_New_Mexico) |
| 25 | San Antonio de Béxar | 1718 | San Antonio, Texas | presidio and villa | [Wikipedia: San Antonio](https://en.wikipedia.org/wiki/San_Antonio) |

**Changes from the current list:**
- All names now use Spanish forms: La Habana, San Agustín, León, Mérida.
- Removed:
  - San Diego and San Francisco (Pacific coast).
  - Panama City (Pacific side).
  - Santiago de los Caballeros (too long and ambiguous).
  - Ciudad Real and Comayagua.
  - Matanzas.
- Added: Concepción de la Vega, Caparra, Nombre de Dios, Bayamo, Vera Cruz, Puebla de los Ángeles, Guadalajara, Zacatecas.
- Pensacola is now given as its period name, Santa María de Galve, and Albuquerque as its period spelling, Alburquerque.
- Capital changed from La Isabela to Santo Domingo.
- Invented: 0.

## Netherlands (`dutch`)

| # | Name | Founded | Location today | Notes | Source |
|---|------|---------|----------------|-------|--------|
| 1 | Nieuw Amsterdam | 1625 | Lower Manhattan, New York | **capital** of New Netherland | [Wikipedia: New Amsterdam](https://en.wikipedia.org/wiki/New_Amsterdam) |
| 2 | Fort Nassau | 1614 | Castle Island, Albany, NY | trading post; flooded out by 1618 (a later Fort Nassau on the Delaware, 1626, is not listed) | [Wikipedia: Fort Nassau (North River)](https://en.wikipedia.org/wiki/Fort_Nassau_(North_River)) |
| 3 | Fort Oranje | 1624 | Albany, NY | trading post | [Wikipedia: Fort Orange](https://en.wikipedia.org/wiki/Fort_Orange) |
| 4 | Nieuw Walcheren | 1628 | Tobago | Zeeland colony, destroyed 1637; **borderline**: south-east corner | [Wikipedia: History of Tobago](https://en.wikipedia.org/wiki/History_of_Tobago) |
| 5 | Pavonia | 1630 | Jersey City, New Jersey | patroonship | [Wikipedia: Pavonia](https://en.wikipedia.org/wiki/Pavonia,_New_Netherland) |
| 6 | Rensselaerswijck | 1630 | around Albany, NY | patroonship of Van Rensselaer; also spelled *-wyck* | [Wikipedia: Rensselaerswyck](https://en.wikipedia.org/wiki/Rensselaerswyck) |
| 7 | Swanendael | 1631 | Lewes, Delaware | whaling colony, destroyed 1632 | [Wikipedia: Zwaanendael Colony](https://en.wikipedia.org/wiki/Zwaanendael_Colony) |
| 8 | Fort de Goede Hoop | 1633 | Hartford, Connecticut | trading post | [Wikipedia: House of Hope](https://en.wikipedia.org/wiki/Fort_Hoop) |
| 9 | Willemstad | 1634 | Curaçao | WIC base founded 1634 as "de Punt"; name Willemstad first recorded 1680; **borderline**: south edge, 12°N | [Wikipedia: Willemstad](https://en.wikipedia.org/wiki/Willemstad) |
| 10 | Vriessendael | 1640 | Edgewater, New Jersey | David de Vries's bouwerie | [Wikipedia: Vriessendael](https://en.wikipedia.org/wiki/Vriessendael) |
| 11 | Vlissingen | 1645 | Flushing, Queens | | [Wikipedia: Flushing](https://en.wikipedia.org/wiki/Flushing,_Queens) |
| 12 | 's-Gravesande | 1645 | Gravesend, Brooklyn | Dutch patent to Lady Deborah Moody's English settlers | [Wikipedia: Gravesend](https://en.wikipedia.org/wiki/Gravesend,_Brooklyn) |
| 13 | Breuckelen | 1646 | Brooklyn | | [Wikipedia: Breuckelen](https://en.wikipedia.org/wiki/Breuckelen_(New_Netherland)) |
| 14 | Nieuw Amersfoort | 1647 | Flatlands, Brooklyn | | [Wikipedia: Flatlands](https://en.wikipedia.org/wiki/Flatlands,_Brooklyn) |
| 15 | Fort Beversreede | 1648 | Philadelphia (Schuylkill) | trading post | [Wikipedia: Fort Beversreede](https://en.wikipedia.org/wiki/Fort_Beversreede) |
| 16 | Beverwijck | 1652 | Albany, NY | town around Fort Oranje | [Wikipedia: Beverwijck](https://en.wikipedia.org/wiki/Beverwijck) |
| 17 | Midwout | 1652 | Flatbush, Brooklyn | | [Wikipedia: Flatbush](https://en.wikipedia.org/wiki/Flatbush,_Brooklyn) |
| 18 | Nieuw Amstel | c. 1655 | New Castle, Delaware | formerly Fort Casimir (1651); city of Amsterdam's colony from 1657 | [Wikipedia: New Castle](https://en.wikipedia.org/wiki/New_Castle,_Delaware) |
| 19 | Nieuw Utrecht | 1657 | New Utrecht, Brooklyn | | [Wikipedia: New Utrecht](https://en.wikipedia.org/wiki/New_Utrecht,_Brooklyn) |
| 20 | Nieuw Haarlem | 1658 | Harlem, Manhattan | | [Wikipedia: Harlem](https://en.wikipedia.org/wiki/History_of_Harlem) |
| 21 | Bergen | 1660 | Jersey City, New Jersey | first chartered town in New Jersey | [Wikipedia: Bergen](https://en.wikipedia.org/wiki/Bergen,_New_Netherland) |
| 22 | Boswijck | 1661 | Bushwick, Brooklyn | | [Wikipedia: Bushwick](https://en.wikipedia.org/wiki/Bushwick,_Brooklyn) |
| 23 | Schenectade | 1661 | Schenectady, NY | Arent van Curler; period spellings vary | [Wikipedia: Schenectady](https://en.wikipedia.org/wiki/Schenectady,_New_York) |
| 24 | Wiltwijck | c. 1652/1661 | Kingston, NY | Esopus settlement 1652; chartered as Wiltwijck 1661; out of date order by one place | [Wikipedia: Kingston NY](https://en.wikipedia.org/wiki/Kingston,_New_York) |
| 25 | Philipsburg | 1763 | Sint Maarten | John Philips, a Scot in Dutch service; the one late Caribbean name | [Wikipedia: Philipsburg](https://en.wikipedia.org/wiki/Philipsburg,_Sint_Maarten) |

**Changes from the current list:**
- Dutch forms used throughout: Nieuw Amsterdam, Fort Oranje, Breuckelen, 's-Gravesande, Boswijck.
- Removed:
  - Oranjestad (an 1824 Aruba name).
  - New Dorp (English-era).
  - The inventions New Utrecht Landing, New Haarlemmermeer, New Zeeland, New Delft and New Rotterdam.
- Added: Nieuw Walcheren, Pavonia, Fort de Goede Hoop, Vriessendael, Nieuw Amersfoort, Fort Beversreede, Bergen.
- Capital changed from Fort Nassau to Nieuw Amsterdam.
- Invented: 0.

## Portugal (`portuguese`)

Portugal founded **no lasting settlement** on this map. Its presence was:
- the Corte-Real voyages (1500–02) and João Fernandes Lavrador (c. 1498–1500);
- seasonal cod-fishing harbours on Newfoundland's Southern Shore, about 1500–1580, whose oldest place names are Portuguese;
- João Álvares Fagundes' short-lived colony on Cape Breton, about 1520–25, whose name and exact site are unknown;
- the naming of Barbados.

Names 1–16 are **real Portuguese place names from the period**, most of them harbours, capes or islands rather than towns. Names 17–25 are **invented in period style**. They draw on the colonists' origins: Fagundes came from Viana do Castelo; the colonists came from the Azores and mainland Portugal; the Corte-Reais were captains of Terceira; and the fishing fleets sailed from Aveiro and Viana. Each was checked not to collide with a real place on the map.

| # | Name | Founded | Location today | Notes | Source |
|---|------|---------|----------------|-------|--------|
| 1 | São João | 1519 (on charts) | St. John's, Newfoundland | **capital**; "R de Sam johan" on the Reinel chart of 1519, before any English use; a Portuguese fishing harbour | [Handcock, Place Names of NL](https://www.gov.nl.ca/landuseatlas/documents/8%20-%20Place%20Names%20of%20Newfoundland%20and%20Labrador%20-%20WG%20Handcock.pdf) |
| 2 | Terra do Lavrador | c. 1500 | Labrador | named after João Fernandes Lavrador; a region name, not a settlement | [Wikipedia: João Fernandes Lavrador](https://en.wikipedia.org/wiki/Jo%C3%A3o_Fernandes_Lavrador) |
| 3 | Baía da Conceição | c. 1500s | Conception Bay, Newfoundland | origin debated (Portuguese tradition); not a settlement | [Handcock, Place Names of NL](https://www.gov.nl.ca/landuseatlas/documents/8%20-%20Place%20Names%20of%20Newfoundland%20and%20Labrador%20-%20WG%20Handcock.pdf) |
| 4 | Cabo Raso | c. 1504 | Cape Race, Newfoundland | "Capo Raso (1504)", the oldest surviving European name in Newfoundland; not a settlement | [Handcock, Toponymic Tour of the Southern Avalon](https://www.gov.nl.ca/landuseatlas/documents/9%20-%20Toponymic%20Tour%20of%20the%20Southern%20Avalon%20-%20The%20Irish%20Loop.pdf) |
| 5 | Ilha dos Bacalhaus | c. 1500s | Baccalieu Island, Newfoundland | from *bacalhau* (cod); not a settlement | [Handcock, Place Names of NL](https://www.gov.nl.ca/landuseatlas/documents/8%20-%20Place%20Names%20of%20Newfoundland%20and%20Labrador%20-%20WG%20Handcock.pdf) |
| 6 | Cabo da Espera | c. 1500s | Cape Spear, Newfoundland | commonly given Portuguese origin; c.; not a settlement | [Wikipedia: Cape Spear](https://en.wikipedia.org/wiki/Cape_Spear) |
| 7 | Farelhão | c. 1500s | Ferryland, Newfoundland | Portuguese fishing station; "Farelhao", later French Forillon | [Handcock, Southern Avalon](https://www.gov.nl.ca/landuseatlas/documents/9%20-%20Toponymic%20Tour%20of%20the%20Southern%20Avalon%20-%20The%20Irish%20Loop.pdf) |
| 8 | Água Forte | c. 1500s | Aquaforte, Newfoundland | fishing harbour; "strong water" (earlier "R. da Agua") | [Handcock, Southern Avalon](https://www.gov.nl.ca/landuseatlas/documents/9%20-%20Toponymic%20Tour%20of%20the%20Southern%20Avalon%20-%20The%20Irish%20Loop.pdf) |
| 9 | Rio Fermoso | 1519 (on charts) | Fermeuse, Newfoundland | Portuguese summer fishing station; "R. fermoso" 1519 | [Handcock, Southern Avalon](https://www.gov.nl.ca/landuseatlas/documents/9%20-%20Toponymic%20Tour%20of%20the%20Southern%20Avalon%20-%20The%20Irish%20Loop.pdf) |
| 10 | Onze Mil Virgens | c. 1520 | Saint-Pierre and Miquelon | Fagundes named the islands after St. Ursula's 11,000 virgins; not a settlement | [Wikipedia: João Álvares Fagundes](https://en.wikipedia.org/wiki/Jo%C3%A3o_%C3%81lvares_Fagundes) |
| 11 | Ilha do Fogo | c. 1500s | Fogo Island, Newfoundland | Portuguese origin commonly given; c.; not a settlement | [Wikipedia: Fogo Island](https://en.wikipedia.org/wiki/Fogo_Island,_Newfoundland_and_Labrador) |
| 12 | Cabo Frei Luís | c. 1500s | Cape Freels, Newfoundland | Portuguese origin commonly given; c.; not a settlement | [Wikipedia: Cape Freels](https://en.wikipedia.org/wiki/Cape_Freels) |
| 13 | Boa Vista | c. 1500s | Bonavista, Newfoundland | Portuguese or Italian origin disputed; c. | [Wikipedia: Bonavista](https://en.wikipedia.org/wiki/Bonavista,_Newfoundland_and_Labrador) |
| 14 | Cabo Bretão | c. 1521–25 | Cape Breton, Nova Scotia | area of Fagundes' colony, Portugal's only settlement attempt here; its own name is unknown | [Wikipedia: João Álvares Fagundes](https://en.wikipedia.org/wiki/Jo%C3%A3o_%C3%81lvares_Fagundes) |
| 15 | Os Barbados | 1536 | Barbados | name given by Pedro a Campos; no settlement | [Wikipedia: Barbados](https://en.wikipedia.org/wiki/History_of_Barbados) |
| 16 | Cabo de Santa Maria | 1536 (on charts) | Cape St. Mary's, Newfoundland | "Capo de Sancta Maria (1536)"; not a settlement | [Handcock, Southern Avalon](https://www.gov.nl.ca/landuseatlas/documents/9%20-%20Toponymic%20Tour%20of%20the%20Southern%20Avalon%20-%20The%20Irish%20Loop.pdf) |
| 17 | Nova Viana | — | — | **invented, in period style**; Fagundes' home port Viana do Castelo | — |
| 18 | São Miguel | — | — | **invented, in period style**; Azorean island that supplied colonists | — |
| 19 | Nova Terceira | — | — | **invented, in period style**; the Corte-Reais were captains of Terceira | — |
| 20 | Vila Franca | — | — | **invented, in period style**; after Vila Franca do Campo, Azores | — |
| 21 | Nossa Senhora da Luz | — | — | **invented, in period style**; a common Portuguese dedication | — |
| 22 | Espírito Santo | — | — | **invented, in period style**; Azorean Holy Spirit devotion | — |
| 23 | Santa Cruz | — | — | **invented, in period style**; an early Portuguese name for new lands (Terra de Santa Cruz) | — |
| 24 | Nova Aveiro | — | — | **invented, in period style**; Aveiro sent cod fleets to the Terra Nova | — |
| 25 | Angra Nova | — | — | **invented, in period style**; after Angra, Terceira | — |

**Changes from the current list:**
- Removed all 23 Brazilian names (off the map), including the anachronistic João Pessoa (a 1930 name).
- Removed "Labrador" and "Terra Nova", which are regions. Terra do Lavrador is kept, as a named region.
- Invented: **9** (#17–25).

## Sweden (`swedish`)

| # | Name | Founded | Location today | Notes | Source |
|---|------|---------|----------------|-------|--------|
| 1 | Fort Christina | 1638 | Wilmington, Delaware | **capital**; first Swedish settlement in North America | [Wikipedia: Fort Christina](https://en.wikipedia.org/wiki/Fort_Christina) |
| 2 | Finland | 1641 | near Marcus Hook, Pennsylvania | also "Chamassungh"; Finnish settlers | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 3 | Upland | 1641 | Chester, Pennsylvania | Fort Mecoponacka; also spelled *Uppland* | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 4 | Fort Nya Elfsborg | 1643 | Salem Co., New Jersey | | [Wikipedia: Fort Nya Elfsborg](https://en.wikipedia.org/wiki/Fort_Nya_Elfsborg) |
| 5 | Fort Nya Götheborg | 1643 | Tinicum Island, Pennsylvania | period spelling (modern *Göteborg*) | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 6 | Printzhof | 1643 | Tinicum, Pennsylvania | Governor Printz's seat | [Wikipedia: Governor Printz Park](https://en.wikipedia.org/wiki/Governor_Printz_Park) |
| 7 | Printztorp | 1643 | Delaware Valley | Printz family farm | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 8 | Provins | 1643 | Province Island, Philadelphia | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 9 | Kingsessing | 1644 | West Philadelphia | the name is Lenape, but it was a Swedish settlement under that name | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 10 | Mölndal | 1645 | Cobbs Creek, Philadelphia | Swedish mill | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 11 | Fort Nya Vasa | 1646 | Kingsessing, Philadelphia | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 12 | Fort Nya Korsholm | 1647 | Schuylkill, Philadelphia | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 13 | Torne | 1647 | Delaware Valley | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 14 | Sveaborg | c. 1649 | Delaware Valley | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 15 | Nya Stockholm | c. 1649 | New Jersey side | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 16 | Fort Trefaldighet | 1654 | New Castle, Delaware | the Dutch Fort Casimir, captured and renamed (also *Trefaldigheten*) | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 17 | Christinahamn | 1654 | Wilmington, Delaware | town laid out by Lindeström behind Fort Christina; burned 1655 | [Delaware Historical: Fort Christina](https://history.delaware.gov/wp-content/uploads/sites/179/2019/01/historyFortChristina.pdf) |
| 18 | Ammansland | 1654 | Delaware Co., Pennsylvania | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 19 | Timmerön | 1654 | Delaware Valley | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 20 | Strandviken | 1654 | Delaware Valley | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 21 | Sidoland | 1654 | Delaware Valley | | [Wikipedia: New Sweden](https://en.wikipedia.org/wiki/New_Sweden) |
| 22 | Wicaco | c. 1669 | South Philadelphia | the name is Lenape; Swedish community with a blockhouse church, later Gloria Dei (1700), under English rule (**weak**) | [Wikipedia: Gloria Dei](https://en.wikipedia.org/wiki/Gloria_Dei_(Old_Swedes%27)_Church) |
| 23 | Gustavia | 1785 | Saint-Barthélemy | Swedish from 1784; Le Carénage renamed c. 1786–87 | [Wikipedia: Gustavia](https://en.wikipedia.org/wiki/Gustavia,_Saint_Barth%C3%A9lemy) |
| 24 | Fort Gustaf | c. 1780s | Gustavia, Saint-Barthélemy | Swedish harbour fort; build date uncertain (**weak**) | [Wikipedia: Gustavia](https://en.wikipedia.org/wiki/Gustavia,_Saint_Barth%C3%A9lemy) |
| 25 | Fort Carl | c. 1780s–90s | Gustavia, Saint-Barthélemy | Swedish harbour fort, also *Fort Karl*; date uncertain (**weak**) | [Wikipedia: Gustavia](https://en.wikipedia.org/wiki/Gustavia,_Saint_Barth%C3%A9lemy) |

**Changes from the current list:**
- Removed:
  - The Swedish African forts Carolusborg, Christiansborg, Batenstein, Fort Witsen, Apollonia and Cabelon.
  - Ruy Coninck.
  - The anachronistic or invented New Uppsala, New Kalmar, New Falun, New Visby and New Karlskrona.
  - Passyunk.
- Added: Printztorp, Provins, Mölndal, Fort Nya Vasa, Sveaborg, Nya Stockholm, Christinahamn, Ammansland, Timmerön, Strandviken, Sidoland, Fort Gustaf, Fort Carl.
- Nya Göteborg is now Fort Nya Götheborg.
- Capital unchanged (Fort Christina).
- Invented: 0, with 3 marked weak.
