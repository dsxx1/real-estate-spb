--Общая статистика по объявлениям
SELECT 
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE days_exposition IS NULL) as null_count,
    100 - ROUND(COUNT(*) FILTER (WHERE days_exposition IS NULL)::decimal / COUNT(*) * 100, 2) as desc_percent,
    MAX(first_day_exposition) as max_date,
    MIN(first_day_exposition) as min_date
FROM real_estate.advertisement a
inner join real_estate.flats f
	on a.id = f.id
left join real_estate.city c
	on c.city_id = f.city_id
--where c.city = 'Санкт-Петербург';


--Просмотр таблицы квартир
select *
from real_estate.flats
limit 1000

--Просмотр справочника городов
select *
from real_estate.city
order by city
limit 1000

--Распределение объявлений по типам населённых пунктов
select 
	COUNT(*) as Колво,
	--city,
	type
from real_estate.flats f
left join real_estate.city c
	on c.city_id=f.city_id 
left join real_estate.type t
	on t.type_id = f.type_id
group by type

--Статистика по времени активности объявлений
SELECT
    MAX(days_exposition) as max_days_exposition,
    MIN(days_exposition) as min_days_exposition,
    ROUND(AVG(days_exposition)::decimal, 2) as avg_days_exposition,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_exposition) as median_days_exposition
FROM real_estate.advertisement a;


--Статистика стоимости квадратного метра
SELECT 
    ROUND(MIN(last_price / total_area)::numeric, 2) as min_sqm_price,
    ROUND(MAX(last_price / total_area)::numeric, 2) as max_sqm_price,
    ROUND(AVG(last_price / total_area)::numeric, 2) as avg_sqm_price,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY last_price / total_area)::numeric, 2) as median_sqm_price
FROM real_estate.advertisement a
inner join real_estate.flats f on a.id = f.id
WHERE last_price > 0 AND total_area > 0;

--Статистика по ключевым числовым параметрам квартир
SELECT
    'total_area' as metric,
    ROUND(MIN(total_area)::numeric, 2) as min_value,
    ROUND(MAX(total_area)::numeric, 2) as max_value,
    ROUND(AVG(total_area)::numeric, 2) as avg_value,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)::numeric, 2) as median,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area)::numeric, 2) as p99
FROM real_estate.flats WHERE total_area > 0
UNION ALL
SELECT
    'rooms',
    ROUND(MIN(rooms)::numeric, 2),
    ROUND(MAX(rooms)::numeric, 2),
    ROUND(AVG(rooms)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rooms)::numeric, 2)
FROM real_estate.flats WHERE rooms >= 0
UNION ALL
SELECT
    'balcony',
    ROUND(MIN(balcony)::numeric, 2),
    ROUND(MAX(balcony)::numeric, 2),
    ROUND(AVG(balcony)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY balcony)::numeric, 2)
FROM real_estate.flats WHERE balcony >= 0
UNION ALL
SELECT
    'ceiling_height',
    ROUND(MIN(ceiling_height)::numeric, 2),
    ROUND(MAX(ceiling_height)::numeric, 2),
    ROUND(AVG(ceiling_height)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ceiling_height)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height)::numeric, 2)
FROM real_estate.flats WHERE ceiling_height > 0
UNION ALL
SELECT
    'floor',
    ROUND(MIN(floor)::numeric, 2),
    ROUND(MAX(floor)::numeric, 2),
    ROUND(AVG(floor)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY floor)::numeric, 2)
FROM real_estate.flats WHERE floor >= 0;


-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);

-- ============================================================
-- ЗАДАЧА 1: Время активности объявлений
-- ============================================================

-- ШАГ 1: Определяем пороговые значения для фильтрации выбросов
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),

-- ШАГ 2: Получаем id объявлений без выбросов
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
            OR ceiling_height IS NULL
        )
),

-- ШАГ 3: Основные данные с категоризацией
prepared AS (
    SELECT
        a.id,

        -- Регион: СПБ или города ЛенОбл
        CASE
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,

        -- Категория по времени активности объявления
        CASE
            WHEN a.days_exposition IS NULL THEN 'non category'
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            ELSE '181+ days'
        END AS activity_category,

        -- Числовые параметры для агрегации
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        f.ceiling_height,
        f.floor,
        f.floors_total,

        -- Стоимость кв.м — считаем здесь, используем в агрегации
        a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm,

        -- Признак студии (0 комнат = открытая планировка / студия)
        CASE WHEN f.rooms = 0 THEN 1 ELSE 0 END AS is_studio,

        -- Признак первого этажа
        CASE WHEN f.floor = 1 THEN 1 ELSE 0 END AS is_first_floor,

        -- Признак последнего этажа
        CASE WHEN f.floor = f.floors_total THEN 1 ELSE 0 END AS is_last_floor

    FROM real_estate.advertisement a
    INNER JOIN real_estate.flats f ON a.id = f.id
    INNER JOIN real_estate.city c ON c.city_id = f.city_id
    INNER JOIN real_estate.type t ON t.type_id = f.type_id
    WHERE
        t.type = 'город'
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
        AND a.id IN (SELECT id FROM filtered_id)
)

-- ШАГ 4: Итоговая сводная таблица
SELECT
    region AS "Регион",
    activity_category AS "Категория активности",

    -- Количество объявлений
    COUNT(id) AS "Количество объявлений",

    -- Доля объявлений внутри каждого региона (в %)
    ROUND(
        COUNT(id)::numeric
        / SUM(COUNT(id)) OVER (PARTITION BY region) * 100, 2
    ) AS "Доля объявлений, %",

    -- Средняя стоимость кв.м
    ROUND(AVG(price_per_sqm)::numeric, 0) AS "Средняя цена за кв.м, руб.",

    -- Средняя площадь
    ROUND(AVG(total_area)::numeric, 1) AS "Средняя площадь, кв.м",

    -- Медиана комнат
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS "Медиана комнат",

    -- Медиана балконов
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS "Медиана балконов",

    -- Средняя высота потолков
    ROUND(AVG(ceiling_height)::numeric, 2) AS "Средняя высота потолков, м",

    -- Доля студий (%) — квартиры с 0 комнат
    ROUND(AVG(is_studio) * 100, 2) AS "Доля студий, %",

    -- Доля квартир на первом этаже (%)
    ROUND(AVG(is_first_floor) * 100, 2) AS "Доля первых этажей, %",

    -- Доля квартир на последнем этаже (%)
    ROUND(AVG(is_last_floor) * 100, 2) AS "Доля последних этажей, %"

FROM prepared
GROUP BY region, activity_category

-- Сортировка: сначала по региону, потом по категории в логичном порядке

order by
    "Регион",
    case
	activity_category
    when '1-30 days' then 1
	when '31-90 days' then 2
	when '91-180 days' then 3
	when '181+ days' then 4
	when 'non category' then 5
end;

/*
Регион         |Категория активности|Количество объявлений|Доля объявлений, %|Средняя цена за кв.м, руб.|Средняя площадь, кв.м|Медиана комнат|Медиана балконов|Средняя высота потолков, м|Доля студий, %|Доля первых этажей, %|Доля последних этажей, %|
---------------+--------------------+---------------------+------------------+--------------------------+---------------------+--------------+----------------+--------------------------+--------------+---------------------+------------------------+
ЛенОбл         |1-30 days           |                  340|             12.02|                     71908|                 48.8|           2.0|             1.0|                      2.70|          0.88|                14.71|                   20.29|
ЛенОбл         |31-90 days          |                  864|             30.55|                     67424|                 50.9|           2.0|             1.0|                      2.71|          0.58|                19.10|                   19.33|
ЛенОбл         |91-180 days         |                  553|             19.55|                     69809|                 51.8|           2.0|             1.0|                      2.70|          0.90|                16.46|                   18.99|
ЛенОбл         |181+ days           |                  873|             30.87|                     68215|                 55.0|           2.0|             1.0|                      2.72|          0.11|                21.08|                   21.08|
ЛенОбл         |non category        |                  198|              7.00|                     72926|                 62.8|           2.0|             1.0|                      2.80|          1.01|                27.78|                   23.74|
Санкт-Петербург|1-30 days           |                 1794|             15.99|                    108920|                 54.7|           2.0|             1.0|                      2.76|          1.56|                 7.58|                   11.26|
Санкт-Петербург|31-90 days          |                 3020|             26.92|                    110874|                 56.6|           2.0|             1.0|                      2.77|          1.19|                 9.24|                   10.20|
Санкт-Петербург|91-180 days         |                 2244|             20.01|                    111974|                 60.5|           2.0|             1.0|                      2.79|          0.58|                 9.49|                   11.59|
Санкт-Петербург|181+ days           |                 3506|             31.26|                    114981|                 65.8|           2.0|             1.0|                      2.83|          0.48|                11.10|                   12.07|
Санкт-Петербург|non category        |                  653|              5.82|                    136108|                 81.4|           3.0|             1.0|                      2.90|          0.46|                11.64|                   12.71|
*/

/*
Выводы:
1. Самые распространённые категории объявлений
В обоих регионах лидирует категория 181+ days объявления, активные более полугода: 31.26% в СПБ и 30.87% в ЛенОбл.
На втором месте — 31-90 days: 26.92% в СПБ и 30.55% в ЛенОбл. Быстрые продажи (1-30 days) составляют лишь 16% и 12% соответственно.
Вывод: рынок недвижимости в обоих регионах медленный. Большинство квартир ищут покупателя от месяца до полугода и дольше. Быстрая продажа скорее исключение, чем норма.

2. Характеристики, влияющие на время активности
Площадь и комнаты главный фактор. С ростом времени активности площадь стабильно увеличивается в обоих регионах: 
от ~49-55 м² в быстрых продажах до ~55-66 м² в долгих. Среднее число комнат растёт с ~1.74-1.87 до ~2.01-2.17.
Цена за кв.м в СПБ растёт вместе со временем активности: от 108 920 до 114 981 руб./м², а у непроданных достигает 136 108 руб./м².
В ЛенОбл зависимость слабее — цены держатся в диапазоне 67-73 тыс. руб./м² без чёткого тренда.
Балконы незначительно, но стабильно: в быстрых продажах их чуть больше (~1.00-1.03), в долгих — меньше (~0.91-0.92).
Наличие балкона слегка повышает привлекательность объекта.
Этаж — важнее в ЛенОбл, чем в СПБ. Доля первых этажей среди долгих объявлений в ЛенОбл достигает 21%, тогда как в быстрых — 14.7%.
Первый и последний этажи сдерживают продажу.
Вывод: быстрее всего продаются компактные квартиры (1-2 комнаты, до 55 м²) с балконом на средних этажах по рыночной цене. 
Крупные и дорогие объекты формируют пул долгих и непроданных объявлений. Премиальные характеристики — большая площадь, 
высокие потолки — не ускоряют продажу, а часто замедляют: это нишевый товар с узкой аудиторией.

3. Различия между СПБ и Ленинградской областью
Цена. СПБ дороже в 1.5-1.7 раза по всем категориям (108-136 тыс. руб./м² против 67-73 тыс. руб./м²).
При этом в СПБ цена растёт вместе со временем активности — дорогие объекты сложнее продать. В ЛенОбл ценовой фактор менее выражен.
Площадь. Квартиры в СПБ крупнее во всех сегментах. Разрыв особенно заметен в непроданных объявлениях: 81.4 м² в СПБ против 62.8 м² в ЛенОбл.
Скорость рынка. СПб чуть активнее — доля быстрых продаж (1-30 days) 16% против 12% в ЛенОбл. Высокий спрос в мегаполисе поглощает даже менее привлекательные объекты быстрее.
Этажность. В ЛенОбл доля первых и последних этажей выше во всех категориях (~14-27% и ~19-24%), что отражает преобладание малоэтажной застройки.
В СПБ этот фактор сглажен высотностью домов и общим спросом.
Вывод: СПБ и ЛенОбл — принципиально разные рынки по ценовому уровню и структуре предложения, но похожи по поведению покупателей.
В обоих регионах компактные стандартные квартиры продаются быстрее крупных и дорогих объектов. Первые этажи — фактор риска прежде всего в ЛенОбл, где малоэтажная застройка делает этот сегмент непропорционально большим среди долгих объявлений.
*/

-- ============================================================
-- ЗАДАЧА 2: Сезонность объявлений
-- ============================================================

-- ШАГ 1: Фильтрация выбросов (стандартный блок)
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),

filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
            OR ceiling_height IS NULL
        )
),

-- ШАГ 2: Базовые данные — для каждого объявления считаем
base AS (
    SELECT
        a.id,

        -- Месяц и год публикации объявления
        DATE_TRUNC('month', a.first_day_exposition) AS publish_month,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publish_month_num,

        -- Дата снятия = дата публикации + количество дней активности
        -- NULL если объявление ещё активно
        a.first_day_exposition + a.days_exposition * INTERVAL '1 day' AS removal_date,
        DATE_TRUNC('month',
            a.first_day_exposition + a.days_exposition * INTERVAL '1 day'
        ) AS removal_month,
        EXTRACT(MONTH FROM
            a.first_day_exposition + a.days_exposition * INTERVAL '1 day'
        ) AS removal_month_num,

        -- Метрики для агрегации
        a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm,
        f.total_area

    FROM real_estate.advertisement a
    INNER JOIN real_estate.flats f ON a.id = f.id
    INNER JOIN real_estate.type t ON t.type_id = f.type_id
    WHERE
        t.type = 'город'                                          -- только города
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 -- полные годы
        AND a.id IN (SELECT id FROM filtered_id)                  -- без выбросов
),

-- ШАГ 3: Статистика по месяцу ПУБЛИКАЦИИ объявлений
stats_publish AS (
    SELECT
        publish_month_num AS month_num,
        COUNT(id) AS publish_count,
        ROUND(AVG(price_per_sqm)::numeric, 0) AS avg_price_per_sqm_pub,
        ROUND(AVG(total_area)::numeric, 1) AS avg_area_pub
    FROM base
    GROUP BY publish_month_num
),

-- ШАГ 4: Статистика по месяцу СНЯТИЯ объявлений
stats_removal AS (
    SELECT
        removal_month_num AS month_num,
        COUNT(id) AS removal_count,
        ROUND(AVG(price_per_sqm)::numeric, 0) AS avg_price_per_sqm_rem,
        ROUND(AVG(total_area)::numeric, 1) AS avg_area_rem
    FROM base
    WHERE
        removal_date IS NOT NULL                       -- только снятые объявления
        AND EXTRACT(YEAR FROM removal_date) BETWEEN 2015 AND 2018 -- снятые в пределах периода
    GROUP BY removal_month_num
)

-- ШАГ 5: Объединяем публикации и снятия в одну таблицу по номеру месяца
SELECT
    p.month_num AS "Номер месяца",
    CASE p.month_num
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS "Месяц",

    -- Активность публикаций
    p.publish_count AS "Количество публикаций",

    -- Доля публикаций от общего числа за год (%)
    ROUND(p.publish_count::numeric / SUM(p.publish_count) OVER () * 100, 2) AS "Доля публикаций, %",

    -- Активность снятий (продаж)
    r.removal_count AS "Количество снятий",

    -- Доля снятий от общего числа за год (%)
    ROUND(r.removal_count::numeric / SUM(r.removal_count) OVER () * 100, 2) AS "Доля снятий, %",

    -- Характеристики по публикациям
    p.avg_price_per_sqm_pub AS "Средняя цена публикаций, руб/м²",
    p.avg_area_pub AS "Средняя площадь публикаций, м²",

    -- Характеристики по снятиям
    r.avg_price_per_sqm_rem AS "Средняя цена снятий, руб/м²",
    r.avg_area_rem AS "Средняя площадь снятий, м²",
    RANK() OVER (ORDER BY p.publish_count DESC) AS "Ранг публикаций",
	RANK() OVER (ORDER BY r.removal_count DESC) AS "Ранг снятий"

FROM stats_publish p
LEFT JOIN stats_removal r ON p.month_num = r.month_num
ORDER BY p.month_num;
/*
Номер месяца|Месяц   |Количество публикаций|Доля публикаций, %|Количество снятий|Доля снятий, %|Средняя цена публикаций, руб/м²|Средняя площадь публикаций, м²|Средняя цена снятий, руб/м²|Средняя площадь снятий, м²|Ранг публикаций|Ранг снятий|
------------+--------+---------------------+------------------+-----------------+--------------+-------------------------------+------------------------------+---------------------------+--------------------------+---------------+-----------+
           1|Январь  |                  735|              5.23|              870|          7.25|                         106106|                          59.2|                     103815|                      57.3|             12|          7|
           2|Февраль |                 1369|              9.75|              740|          6.17|                         103059|                          60.1|                     100820|                      59.6|              3|         11|
           3|Март    |                 1119|              7.97|              818|          6.82|                         102430|                          60.0|                     105165|                      58.4|              8|          8|
           4|Апрель  |                 1021|              7.27|              765|          6.38|                         102632|                          60.6|                     100188|                      56.6|             10|         10|
           5|Май     |                  891|              6.34|              715|          5.96|                         102465|                          59.2|                      99559|                      57.8|             11|         12|
           6|Июнь    |                 1224|              8.71|              771|          6.43|                         104802|                          58.4|                     101864|                      59.8|              5|          9|
           7|Июль    |                 1149|              8.18|             1108|          9.23|                         104489|                          60.4|                     102291|                      58.5|              7|          6|
           8|Август  |                 1166|              8.30|             1137|          9.48|                         107035|                          59.0|                     100037|                      56.8|              6|          5|
           9|Сентябрь|                 1341|              9.55|             1238|         10.32|                         107563|                          61.0|                     104070|                      57.5|              4|          3|
          10|Октябрь |                 1437|             10.23|             1360|         11.34|                         104065|                          59.4|                     104317|                      58.9|              2|          1|
          11|Ноябрь  |                 1569|             11.17|             1301|         10.84|                         105049|                          59.6|                     103791|                      56.7|              1|          2|
          12|Декабрь |                 1024|              7.29|             1175|          9.79|                         104775|                          58.8|                     105505|                      59.3|              9|          4|

/*
Выводы
1. Когда наибольшая активность публикаций и снятий?
Если смотреть на публикации, то продавцы явно предпочитают осень - октябрь и ноябрь стабильно дают максимум новых объявлений
(10.23% и 11.17%). Сентябрь тоже держится высоко (9.55%). Второй, менее выраженный всплеск - февраль (9.75%) и июнь (8.71%).
Январь предсказуемо провальный: всего 5.23% публикаций, рынок только просыпается после праздников.
У покупателей (снятия объявлений) картина немного другая. Осенний сезон они тоже признают - октябрь и ноябрь лидируют (11.34% и 10.84%).
Но летом покупатели заметно активнее продавцов: июль и август дают 9.23% и 9.48% снятий при весьма скромных публикациях. Минимум активности - май и февраль, около 6%.

2. Совпадают ли пики публикаций и снятий?
Осенью - да, совпадают. Сентябрь-ноябрь работает в обе стороны: и продавцы выходят на рынок, и покупатели закрывают сделки.
Это единственный период, когда спрос и предложение разгоняются одновременно.В остальное время картина интереснее.
Февраль - один из самых активных месяцев по публикациям, но по снятиям он почти в самом низу. Продавцы торопятся, покупатели не реагируют.
Эти объявления в итоге доживают до лета или осени. Обратная ситуация в июле–августе: новых объявлений немного, 
зато снятий много - закрываются сделки по объектам, выставленным ещё весной. Декабрь тоже показателен: публикаций мало,
а снятий неожиданно много (9.79%) покупатели явно стараются закрыть сделку до конца года.

3. Как сезон влияет на цену и площадь?
Цена за квадратный метр в целом держится достаточно стабильно на протяжении года - весь разброс укладывается примерно в 8% между минимумом и максимумом.
Тем не менее кое-что заметить можно: август и сентябрь дают самые высокие цены публикаций (107 035 и 107 563 руб./м²).
Логика понятна - продавцы чувствуют приближение активного сезона и выставляют объекты чуть дороже. Весной, напротив, цены скромнее:
март-май держатся около 102 400–102 600 руб./м². Цены снятий при этом ведут себя ровнее — финальная цена сделки почти не зависит от месяца, в котором она закрылась.
Площадь квартир вообще не реагирует на сезон - колебания в пределах 56–61 м² на протяжении всего года, никакого тренда нет. Люди не выбирают, какой метраж покупать, исходя из времени года.

Итог
Осень - единственный сезон, когда рынок работает в полную силу с обеих сторон. Для продавца это лучшее время для выхода, для покупателя - период максимального выбора.
Февраль обманчив: высокая активность публикаций создаёт иллюзию хорошего момента для продажи, но спроса в это время мало. Объявление, поданное в феврале, скорее всего, провисит до лета.
Гнаться за сезонной скидкой при покупке смысла немного - разница в цене между самым дешёвым и самым дорогим месяцем составляет около 8%,
что для рынка недвижимости несущественно. Выбор конкретного объекта всегда важнее выбора месяца.
*/

/*
Общие выводы и рекомендации
Самый ликвидный сегмент в обоих регионах - компактные квартиры 1-2 комнаты,
до 55 кв.м, на средних этажах с балконом. Именно они чаще всего попадают 
в категорию 1-30 дней. В Санкт-Петербурге таких квартир больше и 
оборачиваемость выше: 16% быстрых продаж против 12% в ЛенОбл.

В ЛенОбл стоит избегать первых этажей: они составляют 21% долгих объявлений 
против 14.7% в быстрых продажах.

По сезонности: продавцу выгоднее выходить на рынок в сентябре-ноябре, когда 
активны и продавцы, и покупатели. Февральский всплеск публикаций обманчив - 
в это время спрос низкий и объявление скорее всего провисит до осени.
Покупателю стоит смотреть в июле-августе: новых объявлений мало, зато 
закрываются объекты, выставленные ещё весной, и конкуренция ниже
*/
