package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"cloud.google.com/go/pubsub"
	"github.com/go-redis/redis/v8"
	"github.com/joho/godotenv"
)

var ctx = context.Background()

type App struct {
	RedisClient         *redis.Client
	PubsubTopic         *pubsub.Topic
	HttpClient          *http.Client
	FlagServiceURL      string
	TargetingServiceURL string
}

func main() {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8004"
	}

	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		log.Fatal("REDIS_URL deve ser definida (ex: redis://localhost:6379)")
	}

	flagSvcURL := os.Getenv("FLAG_SERVICE_URL")
	if flagSvcURL == "" {
		log.Fatal("FLAG_SERVICE_URL deve ser definida")
	}

	targetingSvcURL := os.Getenv("TARGETING_SERVICE_URL")
	if targetingSvcURL == "" {
		log.Fatal("TARGETING_SERVICE_URL deve ser definida")
	}

	gcpProjectID := os.Getenv("GCP_PROJECT_ID")
	pubsubTopicID := os.Getenv("PUBSUB_TOPIC_ID")
	if gcpProjectID == "" || pubsubTopicID == "" {
		log.Println("Atenção: GCP_PROJECT_ID/PUBSUB_TOPIC_ID não definidos. Eventos não serão publicados.")
	}

	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Não foi possível parsear a URL do Redis: %v", err)
	}
	rdb := redis.NewClient(opt)
	if _, err := rdb.Ping(ctx).Result(); err != nil {
		log.Fatalf("Não foi possível conectar ao Redis: %v", err)
	}
	log.Println("Conectado ao Redis com sucesso!")

	var topic *pubsub.Topic
	if gcpProjectID != "" && pubsubTopicID != "" {
		client, err := pubsub.NewClient(ctx, gcpProjectID)
		if err != nil {
			log.Fatalf("Não foi possível criar o client do Pub/Sub: %v", err)
		}
		topic = client.Topic(pubsubTopicID)
		log.Println("Client do Pub/Sub inicializado com sucesso.")
	}

	httpClient := &http.Client{
		Timeout: 5 * time.Second,
	}

	app := &App{
		RedisClient:         rdb,
		PubsubTopic:         topic,
		HttpClient:          httpClient,
		FlagServiceURL:      flagSvcURL,
		TargetingServiceURL: targetingSvcURL,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)
	mux.HandleFunc("/evaluate", app.evaluationHandler)

	log.Printf("Serviço de Avaliação (Go) rodando na porta %s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}
