p = 'app/lib/screens/home_page.dart'
data = open(p, 'rb').read()

fixes = [
    (b'\xc3\x83\xe2\x80\x9c', b'\xc3\x93'),  # O with acute (ACELERÓMETRO)
    (b'\xc3\x83\xe2\x80\xb0', b'\xc3\x89'),  # E with acute (MÉTRICAS)
    (b'\xc3\x83\xe2\x80\x94', b'\xc3\x97'),  # multiplication sign (muestras × 6)
    (b'\xc3\x83\xc5\xa1',     b'\xc3\x9a'),  # U with acute (Último/útil)
]

for bad, good in fixes:
    n = data.count(bad)
    if n:
        data = data.replace(bad, good)
        print('Replaced', n, 'occurrences')

open(p, 'wb').write(data)
print('Remaining C3 83:', data.count(b'\xc3\x83'))
