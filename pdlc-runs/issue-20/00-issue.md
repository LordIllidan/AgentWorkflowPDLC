# PDLC Issue Context

Issue: #20 PDLC: dodać 3 algorytmy analizy ryzyk w mieszkalnictwie
URL: https://github.com/LordIllidan/AgentWorkflowPDLC/issues/20

## Body

~~~markdown
## Cel biznesowy

Dodać do przykładowej aplikacji trzy różne algorytmy analizy ryzyk dla mieszkalnictwa, aby można było porównać wyniki oceny ryzyka z kilku perspektyw.

## Zakres

W aplikacji powinny pojawić się trzy algorytmy oceny ryzyka mieszkalnictwa:

1. Algorytm punktowy bazujący na cechach nieruchomości, np. wiek budynku, kondygnacja, zabezpieczenia, historia szkód.
2. Algorytm wagowy bazujący na lokalizacji i ekspozycji, np. ryzyko powodzi, pożaru, kradzieży, gęstość zabudowy.
3. Algorytm regułowy klasyfikujący przypadki specjalne, np. lokal pustostan, budynek drewniany, brak przeglądów, wysoka suma ubezpieczenia.

## Oczekiwane zachowanie

- Backend powinien udostępniać wynik każdego algorytmu osobno.
- Frontend powinien pokazywać porównanie trzech wyników oraz wynik rekomendowany.
- Dla każdego algorytmu powinny istnieć testy jednostkowe albo równoważne testy logiki.
- Dokumentacja powinna opisywać założenia algorytmów i przykładowe dane wejściowe.

## Kryteria akceptacji

- Użytkownik może zobaczyć trzy niezależne wyniki ryzyka mieszkalnictwa.
- System wskazuje rekomendowaną klasyfikację końcową.
- Wyniki są powtarzalne dla tych samych danych wejściowych.
- Algorytmy są opisane w dokumentacji.
- Jeśli agent ma pytania blokujące, powinien zatrzymać proces, zadać pytania w komentarzu i wznowić etap po `/pdlc answer`.
- Zmiana przechodzi przez workflow PDLC od oceny ryzyka autonomii do implementacji.

## Uwagi do PDLC

To issue ma przetestować pełny przepływ:

- automatyczną ocenę ryzyka autonomii po utworzeniu issue,
- utworzenie jednego długowiecznego PR dla issue,
- zapisywanie pełnych artefaktów agentów jako plików w PR,
- pauzę na pytania użytkownika, jeśli agent nie ma danych,
- przejście przez research, analysis, architecture, plan i implementation.
~~~