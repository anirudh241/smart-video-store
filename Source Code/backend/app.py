from flask import Flask, jsonify
import mysql.connector

app = Flask(__name__)

# --- DATABASE CONFIGURATION ---
# Update 'password' with your actual MySQL root password
db_config = {
    'user': 'root',
    'password': 'password',  # <--- CHANGE THIS
    'host': '127.0.0.1',
    'database': 'sakila'
}

# --- THE RECOMMENDATION SUPER QUERY ---
# We use %s placeholders so we can swap in different Customer IDs safely
QUERY_RECOMMENDATIONS = """
WITH 
Target_User_Likes AS (
    SELECT film_id 
    FROM film_reviews 
    WHERE customer_id = %s AND rating_score >= 4
),
Similar_Users AS (
    SELECT DISTINCT fr.customer_id
    FROM film_reviews fr
    JOIN Target_User_Likes tul ON fr.film_id = tul.film_id
    WHERE fr.customer_id != %s AND fr.rating_score >= 4
),
Candidate_Movies AS (
    SELECT 
        fr.film_id,
        COUNT(fr.customer_id) AS recommendation_strength
    FROM film_reviews fr
    JOIN Similar_Users su ON fr.customer_id = su.customer_id
    WHERE fr.rating_score >= 4
    AND fr.film_id NOT IN (SELECT film_id FROM Target_User_Likes)
    GROUP BY fr.film_id
)
SELECT 
    f.title,
    cm.recommendation_strength,
    COUNT(i.inventory_id) AS available_discs,
    GROUP_CONCAT(DISTINCT i.disc_condition) AS conditions
FROM Candidate_Movies cm
JOIN film f ON cm.film_id = f.film_id
JOIN inventory i ON f.film_id = i.film_id
WHERE 
    i.disc_condition != 'Needs Inspection'
    AND i.inventory_id NOT IN (SELECT inventory_id FROM rental WHERE return_date IS NULL)
GROUP BY f.title, cm.recommendation_strength
ORDER BY cm.recommendation_strength DESC, available_discs DESC
LIMIT 10;
"""

def get_db_connection():
    return mysql.connector.connect(**db_config)

@app.route('/')
def home():
    return "<h1>Video Store API is Running!</h1><p>Go to /api/recommendations/1 to test.</p>"

@app.route('/api/recommendations/<int:customer_id>', methods=['GET'])
def get_recommendations(customer_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Execute the query, passing the customer_id twice (for the two %s placeholders)
        cursor.execute(QUERY_RECOMMENDATIONS, (customer_id, customer_id))
        
        results = cursor.fetchall()
        
        # Convert database rows (tuples) into a clean JSON list
        recommendations = []
        for row in results:
            recommendations.append({
                'title': row[0],
                'social_proof': row[1],
                'available_stock': row[2],
                'disc_conditions': row[3]
            })
            
        cursor.close()
        conn.close()
        
        return jsonify(recommendations)

    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Running on 0.0.0.0 makes it accessible to other devices/simulators if needed
    app.run(debug=True, port=5001)