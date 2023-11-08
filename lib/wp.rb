require 'mysql2'
require 'digest/md5'

class WP
  def self.cache
    @@cache ||= {}
  end

  def self.db
    # Connect to the database
    @@db ||= Mysql2::Client.new(
      host: ENV['DB_HOST'] || 'localhost',
      username: ENV['DB_USER'],
      password: ENV['DB_PASS'],
      port: ENV['DB_PORT'] || 3306,
      database: ENV['DB_NAME'],
    )
  end

  # Executes a given MySQL query against the WP database and returns the results.
  # If cache_duration: set to a positive value, caches results for that many seconds.
  def self.query(sql, cache_duration: 0)
    #puts sql # debug
    if (cache_duration > 0) && (cache_key = Digest::MD5.hexdigest(sql)) && (cache_item = cache[cache_key]) && (cache_item[:expiry] > Time.now)
      return cache_item[:value]
    end
    result = db.query(sql)
    (cache[cache_key] = { expiry: Time.now + cache_duration, value: result }) if (cache_duration > 0)
    result
  end

  def self.post_title(post)
    (post['post_title'] == '') ? post['post_name'].gsub('-', ' ').capitalize : post['post_title']
  end

  def self.preview(id)
    query("
      SELECT
        wp_posts.ID, wp_posts.post_date_gmt, wp_posts.post_name, wp_posts.post_title, wp_posts.post_content, wp_postmeta_gemtext.meta_value gemtext
      FROM wp_posts
      LEFT JOIN wp_postmeta wp_postmeta_gemtext ON wp_posts.ID = wp_postmeta_gemtext.post_ID	AND wp_postmeta_gemtext.meta_key='gemtext'
      WHERE wp_posts.ID=#{id.to_i}
      LIMIT 1
    ").to_a[0]
  end

  def self.posts(
    columns: ['wp_posts.ID', 'wp_posts.post_date_gmt', 'wp_posts.post_name', 'wp_posts.post_title', 'wp_posts.post_content', 'wp_postmeta_gemtext.meta_value gemtext'],
    where: ['(1=1)'],
    order_by: 'wp_posts.post_date_gmt DESC',
    limit: 30,
    with_tag: 'published-on-gemini',
    cache_duration: 300
  )
    where << "wp_terms.slug='#{with_tag}'" if with_tag
    where_clauses = where.join(" AND\n ")
    query("
      SELECT
        #{columns.join(', ')}
      FROM wp_terms
      LEFT JOIN wp_term_taxonomy ON wp_terms.term_id = wp_term_taxonomy.term_id
      LEFT JOIN wp_term_relationships ON wp_term_taxonomy.term_taxonomy_id = wp_term_relationships.term_taxonomy_id
      LEFT JOIN wp_posts ON wp_term_relationships.object_id = wp_posts.ID
      LEFT JOIN wp_postmeta wp_postmeta_gemtext ON wp_posts.ID = wp_postmeta_gemtext.post_ID AND wp_postmeta_gemtext.meta_key='gemtext'
      WHERE wp_term_taxonomy.taxonomy='post_tag'
      AND wp_posts.post_type = 'post'
      AND wp_posts.post_status = 'publish'
      AND #{where_clauses}
      ORDER BY #{order_by}
      LIMIT #{limit}
    ", cache_duration: cache_duration).to_a
  end
end
